import SwiftUI

private enum StatsRange: Int, CaseIterable, Identifiable {
    case week = 7
    case twoWeeks = 14
    case month = 30
    case threeMonths = 90

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .week: return "近一周"
        case .twoWeeks: return "近两周"
        case .month: return "近一月"
        case .threeMonths: return "近三月"
        }
    }
}

struct StatsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var extraMl = 250
    @State private var range: StatsRange = .week

    private var theme: Color {
        Color(hex: model.settings.colorHex) ?? Color(red: 0.18, green: 0.61, blue: 1)
    }

    private var days: [DayStat] { model.chartBuckets(lastDays: range.rawValue) }
    private var maxMl: Int { max(days.map(\.ml).max() ?? 0, 1) }
    private var compactChart: Bool { range.rawValue > 14 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(model.todayNarrative())
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    statTile("今日次数", "\(model.countToday()) 次")
                    statTile("今日总量", "\(model.mlToday()) ml")
                    statTile("平均间隔", model.averageGapMinutesToday().map { "\($0) 分钟" } ?? "—")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("今日目标 \(model.mlToday()) / \(model.settings.dailyGoalMl) ml · \(model.goalPercent())%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(theme)
                                .frame(width: max(0, geometry.size.width * model.goalProgress))
                        }
                    }
                    .frame(height: 8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(range.title)
                            .font(.headline)
                        Spacer()
                    }
                    Picker("统计范围", selection: $range) {
                        ForEach(StatsRange.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text(model.rangeSummary(lastDays: range.rawValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if range == .threeMonths {
                        Text("近三月按周汇总，柱顶日期是该周第一天。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    chart
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("今日明细")
                        .font(.headline)
                    if model.drinksToday().isEmpty {
                        Text("今天还没有记录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.drinksToday()) { entry in
                            HStack {
                                Text(model.clock(entry.date))
                                    .font(.system(size: 13, design: .rounded))
                                    .frame(width: 56, alignment: .leading)
                                Text("\(entry.ml) ml")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                Spacer()
                                Button {
                                    model.deleteDrink(id: entry.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                                .help("删除这条记录")
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("补记")
                        .font(.headline)
                    HStack {
                        Stepper(value: $extraMl, in: 50...2000, step: 50) {
                            Text("补记 \(extraMl) ml")
                        }
                        Button("添加") {
                            model.logDrink(ml: extraMl, resetsReminder: false)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme)
                    }
                    Text("补记只计入统计，不会推迟下一次提醒。要重新计时，请在悬浮窗点记一杯。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(model.yearSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: Metrics.stats.width, height: Metrics.stats.height)
        .onAppear { extraMl = model.settings.cupMl }
    }

    private var chart: some View {
        HStack(alignment: .bottom, spacing: compactChart ? 3 : 8) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                let isToday = Calendar.current.isDateInToday(day.id)
                let showLabel = shouldShowLabel(index: index, day: day)
                VStack(spacing: compactChart ? 2 : 4) {
                    if !compactChart {
                        Text(day.ml > 0 ? "\(day.ml)" : " ")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(height: 12)
                    }
                    RoundedRectangle(cornerRadius: compactChart ? 2 : 5, style: .continuous)
                        .fill(isToday ? theme : theme.opacity(0.38))
                        .frame(height: barHeight(day.ml))
                        .help("\(day.label) · \(day.count) 次 · \(day.ml) ml")
                    if !compactChart {
                        Text("\(day.count)次")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    Text(showLabel ? day.label : " ")
                        .font(.system(size: compactChart ? 8 : 11, weight: isToday ? .bold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 168, alignment: .bottom)
    }

    private func shouldShowLabel(index: Int, day: DayStat) -> Bool {
        if Calendar.current.isDateInToday(day.id) { return true }
        switch range {
        case .week, .twoWeeks:
            return true
        case .month:
            return index % 5 == 0 || index == days.count - 1
        case .threeMonths:
            return index % 2 == 0 || index == days.count - 1
        }
    }

    private func barHeight(_ ml: Int) -> CGFloat {
        guard ml > 0 else { return 4 }
        return max(8, CGFloat(ml) / CGFloat(maxMl) * 96)
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
