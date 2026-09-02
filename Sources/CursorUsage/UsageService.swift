import Foundation

enum UsageServiceError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Cursor API"
        case .httpStatus(let code):
            return "Cursor API returned status \(code)"
        case .unauthorized:
            return "Cursor session expired. Sign in to Cursor IDE."
        }
    }
}

final class UsageService {
    private let auth = CursorAuth()
    private let usageSummaryURL = URL(string: "https://cursor.com/api/usage-summary")!
    private let dailySpendURL = URL(string: "https://cursor.com/api/dashboard/get-daily-spend-by-category")!
    private let authMeURL = URL(string: "https://cursor.com/api/auth/me")!
    private let authStripeURL = URL(string: "https://cursor.com/api/auth/stripe")!

    func fetchUsage() async throws -> UsageData {
        let sessionToken = try auth.sessionToken()
        do {
            return try await fetchAll(sessionToken: sessionToken)
        } catch UsageServiceError.unauthorized {
            let refreshed = try await auth.refreshSessionToken()
            return try await fetchAll(sessionToken: refreshed)
        }
    }

    private func fetchAll(sessionToken: String) async throws -> UsageData {
        async let summary = requestJSON(sessionToken: sessionToken, url: usageSummaryURL, body: nil) as UsageSummary
        async let userId = fetchDashboardUserId(sessionToken: sessionToken)
        async let teamId = fetchTeamId(sessionToken: sessionToken)

        let resolvedUserId = try await userId
        let resolvedTeamId = try await teamId
        let (startMs, endMs) = todayPeriodMs()

        let dailyBody: [String: Any] = [
            "teamId": resolvedTeamId,
            "userId": resolvedUserId,
            "periodStartMs": startMs,
            "periodEndMs": endMs,
            "groupBy": 1,
            "spendType": 1,
        ]

        let dailySpend = try await requestJSON(
            sessionToken: sessionToken,
            url: dailySpendURL,
            body: dailyBody
        ) as DailySpendResponse

        return UsageData(summary: try await summary, dailySpend: dailySpend)
    }

    private func fetchDashboardUserId(sessionToken: String) async throws -> Int {
        let me = try await requestJSON(sessionToken: sessionToken, url: authMeURL, body: nil) as AuthMeResponse
        guard let id = me.id else {
            throw UsageServiceError.invalidResponse
        }
        return id
    }

    private func fetchTeamId(sessionToken: String) async throws -> Int {
        let stripe = try await requestJSON(sessionToken: sessionToken, url: authStripeURL, body: nil) as AuthStripeResponse
        guard let teamId = stripe.teamId else {
            throw UsageServiceError.invalidResponse
        }
        return teamId
    }

    private func todayPeriodMs() -> (Int, Int) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-0.001)
        return (Int(start.timeIntervalSince1970 * 1000), Int(end.timeIntervalSince1970 * 1000))
    }

    private func requestJSON<T: Decodable>(
        sessionToken: String,
        url: URL,
        body: [String: Any]?
    ) async throws -> T {
        var request = URLRequest(url: url)
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("https://cursor.com/dashboard/usage", forHTTPHeaderField: "Referer")
            request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        } else {
            request.setValue("https://cursor.com/dashboard/usage", forHTTPHeaderField: "Referer")
        }
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue(
            "WorkosCursorSessionToken=\(sessionToken)",
            forHTTPHeaderField: "Cookie"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UsageServiceError.invalidResponse
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw UsageServiceError.unauthorized
        }
        guard http.statusCode == 200 else {
            throw UsageServiceError.httpStatus(http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
