import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var extraMl = 250

    private var theme: Color {
        Color(hex: model.settings.colorHex) ?? Color(red: 0.18, green: 0.61, blue: 1)
    }

    private var days: [DayStat] { model.recentDays() }
    private var maxMl: Int { max(days.map(\.ml).max() ?? 0, 1) }

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
                    Text("近 7 日")
                        .font(.headline)
                    Text(model.weekSummary())
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(days) { day in
                let isToday = Calendar.current.isDateInToday(day.id)
                VStack(spacing: 4) {
                    Text(day.ml > 0 ? "\(day.ml)" : " ")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isToday ? theme : theme.opacity(0.38))
                        .frame(height: barHeight(day.ml))
                    Text("\(day.count)次")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(day.label)
                        .font(.system(size: 11, weight: isToday ? .bold : .regular))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 168, alignment: .bottom)
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
