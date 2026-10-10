import AppKit
import UserNotifications

enum SystemSettingsLink {
    static func openPrivacySecurity() {
        open([
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:com.apple.preference.security"
        ])
    }

    static func openNotifications() {
        open([
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ])
    }

    private static func open(_ candidates: [String]) {
        for value in candidates {
            guard let url = URL(string: value) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }
}

final class ReminderNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderNotifier()
    static let onboardingKey = "didCompleteOnboarding"

    var onOpen: (() -> Void)?

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    func sendReminder(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "该喝水了"
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "water.reminder.due",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        onOpen?()
        completionHandler()
    }
}
