import SwiftUI

struct UsageView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cursor Usage")
                    .font(.headline)
                Spacer()
                Button(action: appState.refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(appState.isLoading)
            }

            if appState.isLoading && appState.usageData == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let error = appState.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let data = appState.usageData {
                usageContent(data)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    @ViewBuilder
    private func usageContent(_ data: UsageData) -> some View {
        let summary = data.summary

        VStack(alignment: .leading, spacing: 12) {
            dailySummaryCard(data)

            labelRow("Plan", summary.membershipType.capitalized)
            labelRow("Billing", formatBillingCycle(summary))
            labelRow("Working days", "\(WorkingDaysCalculator.workingDaysInCurrentMonth())")

            if let entries = data.dailySpend.dailySpend, entries.count > 1 {
                Divider()
                sectionTitle("By category")
                ForEach(entries.indices, id: \.self) { index in
                    let entry = entries[index]
                    if let cents = entry.spendCents, let category = entry.category {
                        labelRow(categoryLabel(category), MoneyFormat.dollars(fromCents: cents))
                    }
                }
            }

            if let overall = summary.individualUsage?.overall {
                Divider()
                sectionTitle("Monthly included")
                usageRow(
                    used: overall.used,
                    limit: overall.limit,
                    remaining: overall.remaining
                )
            }
        }
    }

  @ViewBuilder
    private func dailySummaryCard(_ data: UsageData) -> some View {
        let percent = data.dailyUsagePercent ?? 0
        let progress = min(percent / 100.0, 1.0)

        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(MoneyFormat.dollars(fromCents: data.dailySpend.totalSpendCents))
                    .font(.title2.weight(.semibold))
                if let quota = data.dailyQuotaCents {
                    Text("/ \(MoneyFormat.dollars(fromCents: quota))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.0f%%", percent))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(progressColor(progress))
            }

            ProgressView(value: progress)
                .tint(progressColor(progress))

            Text("Daily quota = monthly limit ÷ working days")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress >= 1.0 { return .red }
        if progress >= 0.8 { return .orange }
        return .blue
    }

    private func categoryLabel(_ category: String) -> String {
        if category == "default" { return "Default" }
        return category.capitalized
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.top, 4)
    }

    private func labelRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }

    private func usageRow(used: Int?, limit: Int?, remaining: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let used, let limit, limit > 0 {
                let percent = Double(used) / Double(limit)
                ProgressView(value: percent)
                    .tint(percent > 0.8 ? .orange : .blue)
                labelRow("Used / limit", "\(MoneyFormat.dollars(fromCents: used)) / \(MoneyFormat.dollars(fromCents: limit))")
                if let remaining {
                    labelRow("Remaining", MoneyFormat.dollars(fromCents: remaining))
                }
            } else if let used {
                labelRow("Used", MoneyFormat.dollars(fromCents: used))
            }
        }
    }

    private func formatBillingCycle(_ summary: UsageSummary) -> String {
        let start = formatDate(summary.billingCycleStart)
        let end = formatDate(summary.billingCycleEnd)
        return "\(start) – \(end)"
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
    }
}
