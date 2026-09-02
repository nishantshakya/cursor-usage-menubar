import Foundation

struct AppConfig: Decodable {
    let refreshIntervalMinutes: Int?

    var refreshInterval: TimeInterval {
        TimeInterval((refreshIntervalMinutes ?? 15) * 60)
    }

    static func load() -> AppConfig {
        let paths = configPaths()
        for path in paths {
            if FileManager.default.fileExists(atPath: path),
               let data = FileManager.default.contents(atPath: path),
               let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
                return config
            }
        }
        return AppConfig(refreshIntervalMinutes: nil)
    }

    static func configPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.cursor-usage/config.json",
            "\(home)/.config/cursor-usage/config.json",
        ]
    }
}
