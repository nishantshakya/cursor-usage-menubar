import Foundation

struct UsageSummary: Decodable {
    let billingCycleStart: String
    let billingCycleEnd: String
    let membershipType: String
    let limitType: String
    let isUnlimited: Bool
    let autoModelSelectedDisplayMessage: String?
    let namedModelSelectedDisplayMessage: String?
    let individualUsage: IndividualUsage?
    let teamUsage: TeamUsage?

    struct UsageBucket: Decodable {
        let enabled: Bool?
        let used: Int?
        let limit: Int?
        let remaining: Int?
    }

    struct IndividualUsage: Decodable {
        let overall: UsageBucket?
    }

    struct TeamUsage: Decodable {
        let onDemand: UsageBucket?
    }
}

struct DailySpendResponse: Decodable {
    let dailySpend: [DailySpendEntry]?
    let categories: [String]?

    struct DailySpendEntry: Decodable {
        let day: String?
        let category: String?
        let spendCents: Int?
        let totalTokens: String?
    }

    var totalSpendCents: Int {
        dailySpend?.compactMap(\.spendCents).reduce(0, +) ?? 0
    }
}

struct AuthMeResponse: Decodable {
    let id: Int?
}

struct AuthStripeResponse: Decodable {
    let teamId: Int?
}

struct UsageData {
    let summary: UsageSummary
    let dailySpend: DailySpendResponse

    var dailyQuotaCents: Double? {
        guard let limit = summary.individualUsage?.overall?.limit, limit > 0 else { return nil }
        let workingDays = WorkingDaysCalculator.workingDaysInCurrentMonth()
        guard workingDays > 0 else { return nil }
        return Double(limit) / Double(workingDays)
    }

    var dailyUsagePercent: Double? {
        guard let quota = dailyQuotaCents, quota > 0 else { return nil }
        return Double(dailySpend.totalSpendCents) / quota * 100
    }
}

enum MoneyFormat {
    static func dollars(fromCents cents: Int) -> String {
        dollars(fromCents: Double(cents))
    }

    static func dollars(fromCents cents: Double) -> String {
        let dollars = cents / 100.0
        if abs(dollars - floor(dollars)) < 0.005 {
            return String(format: "$%.0f", dollars)
        }
        return String(format: "$%.2f", dollars)
    }
}
