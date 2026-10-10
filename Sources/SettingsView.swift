import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    private var theme: Color {
        Color(hex: model.settings.colorHex) ?? Color(red: 0.18, green: 0.61, blue: 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox("提醒间隔") {
                    VStack(alignment: .leading, spacing: 10) {
                        Stepper(value: intervalBinding, in: 1...240) {
                            Text("每 \(model.settings.intervalMinutes) 分钟提醒一次")
                        }
                        HStack(spacing: 8) {
                            ForEach([20, 30, 45, 60, 90], id: \.self) { minutes in
                                Button("\(minutes) 分钟") { model.setInterval(minutes) }
                                    .buttonStyle(.bordered)
                                    .tint(model.settings.intervalMinutes == minutes ? theme : .gray)
                            }
                        }
                        Toggle("暂停提醒", isOn: pauseBinding)
                        Text("修改间隔后，会从上次喝水或跳过的时间重新计算。暂停期间仍可以记一杯。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("提示语") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("该喝水啦，起来活动一下", text: messageBinding)
                            .textFieldStyle(.roundedBorder)
                        Text("\(model.settings.message.count)/40 · 到时间后显示在悬浮窗上")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("提醒颜色") {
                    VStack(alignment: .leading, spacing: 10) {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.fixed(32), spacing: 8), count: 8),
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(Palette.presets, id: \.self) { hex in
                                colorSwatch(hex)
                            }
                        }
                        ColorPicker("自定义颜色", selection: colorBinding, supportsOpacity: false)
                        Text("到时间后，悬浮窗会变成这个颜色。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("提醒声音") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Picker("提醒声音", selection: soundBinding) {
                                Text("无").tag("")
                                ForEach(model.availableSounds) { sound in
                                    Text(sound.title).tag(sound.name)
                                }
                            }
                            .labelsHidden()
                            Button("试听") { model.playSound() }
                                .disabled(model.settings.soundName.isEmpty)
                        }
                        Text("未处理提醒时，每分钟会再响一次，直到记一杯、稍后或跳过。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("权限") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("如果双击打不开，或到点没有通知，到系统设置里打开权限。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button("允许打开应用") { SystemSettingsLink.openPrivacySecurity() }
                            Button("通知权限") { SystemSettingsLink.openNotifications() }
                        }
                    }
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("饮水量") {
                    VStack(alignment: .leading, spacing: 8) {
                        Stepper(value: cupBinding, in: 50...2000, step: 50) {
                            Text("每次 \(model.settings.cupMl) ml")
                        }
                        Stepper(value: goalBinding, in: 100...10000, step: 100) {
                            Text("每日目标 \(model.settings.dailyGoalMl) ml")
                        }
                        Text("悬浮窗上的加减也会改每次饮水量。总量按每次记录累加。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: { model.previewReminder() }) {
                    Text("预览提醒效果")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme)
                .help("在悬浮窗上预览颜色、提示语和声音")

                VStack(alignment: .leading, spacing: 4) {
                    Text("数据保存在本机")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.storeURL.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(16)
        }
        .frame(width: Metrics.settings.width, height: Metrics.settings.height)
    }

    private var intervalBinding: Binding<Int> {
        Binding(get: { model.settings.intervalMinutes }, set: { model.setInterval($0) })
    }

    private var pauseBinding: Binding<Bool> {
        Binding(get: { model.settings.paused }, set: { model.setPaused($0) })
    }

    private var messageBinding: Binding<String> {
        Binding(get: { model.settings.message }, set: { model.setMessage($0) })
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { theme },
            set: { model.setColor(NSColor($0).hexString) }
        )
    }

    private var soundBinding: Binding<String> {
        Binding(get: { model.settings.soundName }, set: { model.setSound($0) })
    }

    private var cupBinding: Binding<Int> {
        Binding(get: { model.settings.cupMl }, set: { model.setCup($0) })
    }

    private var goalBinding: Binding<Int> {
        Binding(get: { model.settings.dailyGoalMl }, set: { model.setGoal($0) })
    }

    private func colorSwatch(_ hex: String) -> some View {
        let selected = model.settings.colorHex.caseInsensitiveCompare(hex) == .orderedSame
        let color = Color(hex: hex) ?? theme
        return Button {
            model.setColor(hex)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 26, height: 26)
                .overlay(
                    Circle().strokeBorder(Color.primary.opacity(selected ? 0.85 : 0.15), lineWidth: selected ? 2 : 1)
                )
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color.prefersDarkText ? Color.black : Color.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("颜色 \(hex)")
    }
}
