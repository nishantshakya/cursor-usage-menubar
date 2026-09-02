import Foundation
import SQLite3

enum CursorAuthError: LocalizedError {
    case databaseNotFound
    case cursorAppNotFound
    case oauthClientIDNotFound
    case notLoggedIn
    case invalidToken
    case refreshFailed(String)
    case refreshRejected

    var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "Cursor IDE data not found. Install Cursor and sign in."
        case .cursorAppNotFound:
            return "Cursor IDE app not found. Install Cursor desktop app."
        case .oauthClientIDNotFound:
            return "Could not read OAuth client ID from Cursor IDE installation."
        case .notLoggedIn:
            return "Not signed in to Cursor IDE. Open Cursor and sign in."
        case .invalidToken:
            return "Invalid Cursor session token."
        case .refreshFailed(let detail):
            return "Failed to refresh Cursor session: \(detail)"
        case .refreshRejected:
            return "Cursor session expired. Sign in to Cursor IDE again."
        }
    }
}

/// Reads session auth from Cursor IDE's local database and refreshes via OAuth when needed.
final class CursorAuth {
    private static let refreshURL = URL(string: "https://api2.cursor.sh/oauth/token")!
    private static let oauthClientIDPattern =
        #"="([A-Za-z0-9]{32})",[a-zA-Z$][a-zA-Z0-9$]*="prod\.authentication\.cursor\.sh""#
    private static var cachedOAuthClientID: String?

    /// Reads the current access token from Cursor IDE (refreshed automatically by the IDE).
    func sessionToken() throws -> String {
        let accessToken = try readAccessTokenFromIDE()
        return try buildSessionToken(accessToken: accessToken)
    }

    /// Refreshes tokens via Cursor's OAuth endpoint when the web session cookie is stale.
    func refreshSessionToken() async throws -> String {
        let refreshToken = try readRefreshTokenFromIDE()
        let accessToken = try await refreshAccessToken(refreshToken: refreshToken)
        return try buildSessionToken(accessToken: accessToken)
    }

    private func readAccessTokenFromIDE() throws -> String {
        let token = try readDatabaseKey("cursorAuth/accessToken")
        guard !token.isEmpty else { throw CursorAuthError.notLoggedIn }
        return token
    }

    private func readRefreshTokenFromIDE() throws -> String {
        let token = try readDatabaseKey("cursorAuth/refreshToken")
        guard !token.isEmpty else { throw CursorAuthError.notLoggedIn }
        return token
    }

    private func readDatabaseKey(_ key: String) throws -> String {
        let path = cursorDatabasePath()
        guard FileManager.default.fileExists(atPath: path) else {
            throw CursorAuthError.databaseNotFound
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw CursorAuthError.databaseNotFound
        }
        defer { sqlite3_close(db) }

        let query = "SELECT value FROM ItemTable WHERE key = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw CursorAuthError.notLoggedIn
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, key, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw CursorAuthError.notLoggedIn
        }
        guard let cString = sqlite3_column_text(statement, 0) else {
            throw CursorAuthError.notLoggedIn
        }
        return String(cString: cString)
    }

    private func cursorDatabasePath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    }

    private func buildSessionToken(accessToken: String) throws -> String {
        let userId = try userIdFromJWT(accessToken)
        return "\(userId)::\(accessToken)"
    }

    private func userIdFromJWT(_ jwt: String) throws -> String {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { throw CursorAuthError.invalidToken }

        var base64 = String(parts[1])
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padding)

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else {
            throw CursorAuthError.invalidToken
        }

        if let pipeIndex = sub.firstIndex(of: "|") {
            return String(sub[sub.index(after: pipeIndex)...])
        }
        return sub
    }

    private func oauthClientID() throws -> String {
        if let cached = Self.cachedOAuthClientID {
            return cached
        }
        let clientID = try Self.extractOAuthClientIDFromCursorApp()
        Self.cachedOAuthClientID = clientID
        return clientID
    }

    private static func extractOAuthClientIDFromCursorApp() throws -> String {
        for path in cursorWorkbenchPaths() {
            guard let data = FileManager.default.contents(atPath: path),
                  let contents = String(data: data, encoding: .utf8) else {
                continue
            }
            guard let regex = try? NSRegularExpression(pattern: oauthClientIDPattern),
                  let match = regex.firstMatch(
                    in: contents,
                    range: NSRange(contents.startIndex..., in: contents)
                  ),
                  let range = Range(match.range(at: 1), in: contents) else {
                continue
            }
            return String(contents[range])
        }
        throw cursorWorkbenchPaths().isEmpty ? CursorAuthError.cursorAppNotFound : CursorAuthError.oauthClientIDNotFound
    }

    private static func cursorWorkbenchPaths() -> [String] {
        let workbenchFiles = [
            "Contents/Resources/app/out/vs/workbench/workbench.desktop.main.js",
            "Contents/Resources/app/out/vs/workbench/workbench.glass.main.js",
        ]
        return cursorAppPaths().flatMap { app in
            workbenchFiles.map { "\(app)/\($0)" }
        }
    }

    private static func cursorAppPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/Applications/Cursor.app",
            "\(home)/Applications/Cursor.app",
        ]
    }

    private func refreshAccessToken(refreshToken: String) async throws -> String {
        let payload: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": try oauthClientID(),
            "refresh_token": refreshToken,
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: Self.refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CursorAuthError.refreshFailed("Invalid response")
        }
        guard http.statusCode == 200 else {
            throw CursorAuthError.refreshFailed("HTTP \(http.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CursorAuthError.refreshFailed("Invalid JSON")
        }

        if json["shouldLogout"] as? Bool == true {
            throw CursorAuthError.refreshRejected
        }

        guard let accessToken = json["access_token"] as? String, !accessToken.isEmpty else {
            throw CursorAuthError.refreshFailed("Missing access_token")
        }

        return accessToken
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
