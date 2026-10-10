import AppKit
import Foundation
import SwiftUI

enum SelfTest {
    static func run() -> Int32 {
        var failed = 0

        func check(_ name: String, _ condition: @autoclosure () -> Bool) {
            if condition() {
                print("PASS \(name)")
            } else {
                print("FAIL \(name)")
                failed += 1
            }
        }

        func temporaryURL() -> URL {
            FileManager.default.temporaryDirectory
                .appendingPathComponent("water-reminder-\(UUID().uuidString).json")
        }

        check("hex", NSColor(hex: "#2E9BFF")?.hexString == "#2E9BFF")
        check("hex short", NSColor(hex: "34C759")?.hexString == "#34C759")
        check("hex bad", NSColor(hex: "nope") == nil)
        check("light color", Color(hex: "#FFD60A")?.prefersDarkText == true)
        check("dark color", Color(hex: "#2E9BFF")?.prefersDarkText == false)

        let corruptURL = temporaryURL()
        try? Data("not json".utf8).write(to: corruptURL)
        let corruptModel = AppModel(storeURL: corruptURL, startTimer: false)
        check("corrupt falls back", corruptModel.settings.intervalMinutes == 45)
        try? FileManager.default.removeItem(at: corruptURL)
        try? FileManager.default.removeItem(at: corruptURL.deletingPathExtension().appendingPathExtension("bad.json"))

        let statsURL = temporaryURL()
        defer { try? FileManager.default.removeItem(at: statsURL) }
        let stats = AppModel(storeURL: statsURL, startTimer: false)
        let start = Calendar.current.startOfDay(for: Date())
        stats.logDrink(ml: 250, at: start.addingTimeInterval(3 * 3600), resetsReminder: false)
        stats.logDrink(ml: 500, at: start.addingTimeInterval(4 * 3600), resetsReminder: false)
        stats.logDrink(ml: 100, at: start.addingTimeInterval(-3600), resetsReminder: false)
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: start) ?? start
        stats.logDrink(ml: 50, at: eightDaysAgo, resetsReminder: false)
        check("today ml \(stats.mlToday())", stats.mlToday() == 750)
        check("today count \(stats.countToday())", stats.countToday() == 2)
        check("gap \(stats.averageGapMinutesToday() ?? -1)", stats.averageGapMinutesToday() == 60)
        check("week ml \(stats.summary(lastDays: 7).ml)", stats.summary(lastDays: 7).ml == 850)
        check("week count \(stats.summary(lastDays: 7).count)", stats.summary(lastDays: 7).count == 3)
        check("seven buckets", stats.recentDays().count == 7)
        check("month buckets", stats.recentDays(30).count == 30)
        check("quarter weeks", stats.recentWeeks(coveringDays: 90).count == 13)
        check("chart month daily", stats.chartBuckets(lastDays: 30).count == 30)
        check("chart quarter weekly", stats.chartBuckets(lastDays: 90).count == 13)
        check("range text", stats.rangeSummary(lastDays: 30).contains("近 30 日"))
        check("archive keeps older", stats.drinks.contains { $0.ml == 50 })
        check("goal capped", abs(stats.goalProgress - min(1, 750.0 / 2000.0)) < 0.001)
        if let todayID = stats.drinksToday().first?.id {
            stats.deleteDrink(id: todayID)
            check("delete one", stats.mlToday() == 250 || stats.mlToday() == 500)
        } else {
            check("delete one", false)
        }

        let storeURL = temporaryURL()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let original = AppModel(storeURL: storeURL, startTimer: false)
        original.setMessage("喝水时间到")
        original.setColor("2e9bff")
        original.setInterval(25)
        original.setCup(300)
        original.logDrink(ml: 180, resetsReminder: false)
        let loaded = AppModel(storeURL: storeURL, startTimer: false)
        check("persist message", loaded.settings.message == "喝水时间到")
        check("persist color", loaded.settings.colorHex == "#2E9BFF")
        check("persist interval", loaded.settings.intervalMinutes == 25)
        check("persist cup", loaded.settings.cupMl == 300)
        check("persist ml", loaded.mlToday() == 180)
        check(
            "persist next",
            abs(loaded.nextReminder.timeIntervalSince(original.nextReminder)) < 1
        )

        let scheduleURL = temporaryURL()
        defer { try? FileManager.default.removeItem(at: scheduleURL) }
        let schedule = AppModel(storeURL: scheduleURL, startTimer: false)
        let acknowledged = schedule.lastAck
        schedule.setInterval(10)
        check(
            "interval reschedule",
            abs(schedule.nextReminder.timeIntervalSince(acknowledged) - 600) < 1.5
        )
        schedule.setInterval(0)
        check("interval min", schedule.settings.intervalMinutes == 1)
        schedule.setInterval(999)
        check("interval max", schedule.settings.intervalMinutes == 240)

        let remindURL = temporaryURL()
        defer { try? FileManager.default.removeItem(at: remindURL) }
        let remind = AppModel(storeURL: remindURL, startTimer: false)
        var sounds: [String] = []
        remind.soundHook = { sounds.append($0) }
        remind.lastAck = Date().addingTimeInterval(-7200)
        remind.nextReminder = Date().addingTimeInterval(-30)
        remind.evaluateReminder()
        check("starts reminding", remind.isReminding)
        check("plays once", sounds == ["Glass"])
        remind.evaluateReminder()
        check("no immediate repeat", sounds == ["Glass"])
        remind.lastSoundAt = Date().addingTimeInterval(-70)
        remind.evaluateReminder()
        check("repeats after a minute", sounds == ["Glass", "Glass"])
        remind.snooze(minutes: 5)
        check("snooze clears", remind.isReminding == false)
        let snoozeLeft = remind.nextReminder.timeIntervalSinceNow
        check("snooze about 5 min \(snoozeLeft)", snoozeLeft > 290 && snoozeLeft < 310)
        remind.evaluateReminder()
        check("quiet during snooze", sounds == ["Glass", "Glass"])

        let kept = remind.nextReminder
        remind.logDrink(ml: 100, at: Date().addingTimeInterval(-86_400), resetsReminder: false)
        check("history keeps schedule", remind.nextReminder == kept)

        remind.isReminding = true
        remind.settings.intervalMinutes = 15
        remind.skipReminder()
        check("skip clears", remind.isReminding == false)
        check(
            "skip reschedules",
            abs(remind.nextReminder.timeIntervalSinceNow - 900) < 2
        )

        remind.isReminding = true
        remind.logDrink(ml: 250)
        check("log clears reminder", remind.isReminding == false)
        check("every sip celebrates", remind.celebration == .sip(ml: 250))

        let prizeURL = temporaryURL()
        defer { try? FileManager.default.removeItem(at: prizeURL) }
        let prize = AppModel(storeURL: prizeURL, startTimer: false)
        check("bundled default bg", prize.rewardBackground != nil)
        check("no custom file yet", prize.settings.rewardBackgroundFile == nil)
        prize.settings.dailyGoalMl = 300
        prize.settings.cupMl = 200
        prize.soundHook = { _ in }
        prize.logDrink(ml: 200)
        check("plain drink celebrates", prize.celebration == .sip(ml: 200))
        prize.clearCelebration()
        prize.isReminding = true
        prize.logDrink(ml: 150)
        check("crossing goal", prize.celebration == .goal(ml: 150))
        prize.clearCelebration()
        check("clear celebration", prize.celebration == .none)
        prize.logDrink(ml: 200)
        check("another sip still celebrates", prize.celebration == .sip(ml: 200))

        let imageURL = FileManager.default.temporaryDirectory.appendingPathComponent("reward-src.png")
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=")
        try? png?.write(to: imageURL)
        check("set reward bg", prize.setRewardBackground(from: imageURL))
        check("reward file", prize.settings.rewardBackgroundFile == "reward-bg.jpg")
        check("reward image loaded", prize.rewardBackground != nil)
        let reloadedBg = AppModel(storeURL: prizeURL, startTimer: false)
        check("reward persists", reloadedBg.rewardBackground != nil)
        reloadedBg.clearRewardBackground()
        check("custom file cleared", reloadedBg.settings.rewardBackgroundFile == nil)
        check("default reward remains", reloadedBg.rewardBackground != nil)
        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: prizeURL.deletingLastPathComponent().appendingPathComponent("reward-bg.jpg"))
        check(
            "log reschedules",
            abs(remind.nextReminder.timeIntervalSince(remind.lastAck) - Double(remind.settings.intervalMinutes * 60)) < 1.5
        )

        let pauseURL = temporaryURL()
        defer { try? FileManager.default.removeItem(at: pauseURL) }
        let paused = AppModel(storeURL: pauseURL, startTimer: false)
        var pauseSounds = 0
        paused.soundHook = { _ in pauseSounds += 1 }
        paused.setPaused(true)
        paused.nextReminder = Date().addingTimeInterval(-10)
        paused.evaluateReminder()
        check("paused stays quiet", paused.isReminding == false && pauseSounds == 0)
        paused.setPaused(false)
        check("resume reminds", paused.isReminding && pauseSounds == 1)

        let overdueURL = temporaryURL()
        defer { try? FileManager.default.removeItem(at: overdueURL) }
        let overdue = AppModel(storeURL: overdueURL, startTimer: false)
        overdue.lastAck = Date().addingTimeInterval(-3600)
        overdue.nextReminder = Date().addingTimeInterval(-20)
        overdue.save()
        let reloaded = AppModel(storeURL: overdueURL, startTimer: false)
        var reloadedSounds = 0
        reloaded.soundHook = { _ in reloadedSounds += 1 }
        reloaded.evaluateReminder()
        check("overdue after relaunch", reloaded.isReminding && reloadedSounds == 1)

        check("empty message", {
            let model = AppModel(storeURL: temporaryURL(), startTimer: false)
            model.setMessage("   ")
            return model.reminderMessage == "该喝水啦"
        }())

        if failed == 0 {
            print("All tests passed")
            return 0
        }
        print("\(failed) failed")
        return 1
    }
}
