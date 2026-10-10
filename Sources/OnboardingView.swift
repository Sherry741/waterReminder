import SwiftUI
import UserNotifications

struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var requesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(red: 0.18, green: 0.61, blue: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text("开始使用 waterReminder")
                        .font(.title2.weight(.semibold))
                    Text("先打开系统权限，提醒才能正常弹出")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Text("这个应用没有苹果公证。如果刚才双击时看到「无法验证」，先去系统设置允许打开；然后打开通知权限，到点才会在通知中心提醒你。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            permissionRow(
                title: "1. 允许打开这个应用",
                detail: "系统设置 → 隐私与安全性 → 拉到下面点「仍要打开」",
                done: false,
                button: "去系统设置"
            ) {
                SystemSettingsLink.openPrivacySecurity()
            }

            permissionRow(
                title: "2. 打开通知权限",
                detail: notificationDetail,
                done: notificationStatus == .authorized,
                button: notificationButtonTitle
            ) {
                handleNotificationTapped()
            }

            Spacer(minLength: 8)

            Button(action: finish) {
                Text("开始使用")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(22)
        .frame(width: 460, height: 420)
        .onAppear(perform: refreshStatus)
    }

    private var notificationDetail: String {
        switch notificationStatus {
        case .authorized:
            return "已打开，到点会弹出通知"
        case .denied:
            return "当前是关闭的，需要到系统设置里重新打开"
        default:
            return "用于到点提醒。点按钮后，在系统弹窗里选「允许」"
        }
    }

    private var notificationButtonTitle: String {
        switch notificationStatus {
        case .authorized:
            return "已打开"
        case .denied:
            return "去系统设置"
        default:
            return requesting ? "请求中…" : "打开通知权限"
        }
    }

    private func permissionRow(
        title: String,
        detail: String,
        done: Bool,
        button: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
                .font(.title3)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(button, action: action)
                    .disabled(done || requesting)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func handleNotificationTapped() {
        switch notificationStatus {
        case .denied:
            SystemSettingsLink.openNotifications()
        case .authorized:
            break
        default:
            requesting = true
            ReminderNotifier.shared.requestPermission { granted in
                requesting = false
                refreshStatus()
                if !granted {
                    SystemSettingsLink.openNotifications()
                }
            }
        }
    }

    private func refreshStatus() {
        ReminderNotifier.shared.authorizationStatus { notificationStatus = $0 }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: ReminderNotifier.onboardingKey)
        onFinished()
    }
}
