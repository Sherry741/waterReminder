import AppKit
import Combine
import Foundation

struct DrinkEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var ml: Int
}

struct DayStat: Identifiable, Equatable {
    var id: Date
    var label: String
    var count: Int
    var ml: Int
}

struct SoundOption: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var title: String
}

struct Settings: Codable, Equatable {
    var intervalMinutes: Int
    var message: String
    var colorHex: String
    var soundName: String
    var cupMl: Int
    var dailyGoalMl: Int
    var paused: Bool
    var windowX: Double?
    var windowY: Double?
    var windowWidth: Double?
    var windowHeight: Double?
    var collapsed: Bool
    var bubbleX: Double?
    var bubbleY: Double?
    /// 1 是旧的大窗口，2 起按约 4 厘米的主界面保存尺寸。
    var layoutVersion: Int

    init(
        intervalMinutes: Int = 45,
        message: String = "该喝水啦，起来活动一下",
        colorHex: String = "#2E9BFF",
        soundName: String = "Glass",
        cupMl: Int = 250,
        dailyGoalMl: Int = 2000,
        paused: Bool = false,
        windowX: Double? = nil,
        windowY: Double? = nil,
        windowWidth: Double? = nil,
        windowHeight: Double? = nil,
        collapsed: Bool = false,
        bubbleX: Double? = nil,
        bubbleY: Double? = nil,
        layoutVersion: Int = 2
    ) {
        self.intervalMinutes = intervalMinutes
        self.message = message
        self.colorHex = colorHex
        self.soundName = soundName
        self.cupMl = cupMl
        self.dailyGoalMl = dailyGoalMl
        self.paused = paused
        self.windowX = windowX
        self.windowY = windowY
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.collapsed = collapsed
        self.bubbleX = bubbleX
        self.bubbleY = bubbleY
        self.layoutVersion = layoutVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intervalMinutes = try container.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? 45
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? "该喝水啦，起来活动一下"
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#2E9BFF"
        soundName = try container.decodeIfPresent(String.self, forKey: .soundName) ?? "Glass"
        cupMl = try container.decodeIfPresent(Int.self, forKey: .cupMl) ?? 250
        dailyGoalMl = try container.decodeIfPresent(Int.self, forKey: .dailyGoalMl) ?? 2000
        paused = try container.decodeIfPresent(Bool.self, forKey: .paused) ?? false
        windowX = try container.decodeIfPresent(Double.self, forKey: .windowX)
        windowY = try container.decodeIfPresent(Double.self, forKey: .windowY)
        windowWidth = try container.decodeIfPresent(Double.self, forKey: .windowWidth)
        windowHeight = try container.decodeIfPresent(Double.self, forKey: .windowHeight)
        collapsed = try container.decodeIfPresent(Bool.self, forKey: .collapsed) ?? false
        bubbleX = try container.decodeIfPresent(Double.self, forKey: .bubbleX)
        bubbleY = try container.decodeIfPresent(Double.self, forKey: .bubbleY)
        layoutVersion = try container.decodeIfPresent(Int.self, forKey: .layoutVersion) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(intervalMinutes, forKey: .intervalMinutes)
        try container.encode(message, forKey: .message)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(soundName, forKey: .soundName)
        try container.encode(cupMl, forKey: .cupMl)
        try container.encode(dailyGoalMl, forKey: .dailyGoalMl)
        try container.encode(paused, forKey: .paused)
        try container.encodeIfPresent(windowX, forKey: .windowX)
        try container.encodeIfPresent(windowY, forKey: .windowY)
        try container.encodeIfPresent(windowWidth, forKey: .windowWidth)
        try container.encodeIfPresent(windowHeight, forKey: .windowHeight)
        try container.encode(collapsed, forKey: .collapsed)
        try container.encodeIfPresent(bubbleX, forKey: .bubbleX)
        try container.encodeIfPresent(bubbleY, forKey: .bubbleY)
        try container.encode(layoutVersion, forKey: .layoutVersion)
    }

    func clamped() -> Settings {
        var copy = self
        copy.intervalMinutes = min(240, max(1, intervalMinutes))
        copy.cupMl = min(2000, max(50, cupMl))
        copy.dailyGoalMl = min(10000, max(100, dailyGoalMl))
        copy.message = String(message.prefix(40))
        if let color = NSColor(hex: copy.colorHex) {
            copy.colorHex = color.hexString
        } else {
            copy.colorHex = "#2E9BFF"
        }
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case intervalMinutes, message, colorHex, soundName, cupMl, dailyGoalMl, paused
        case windowX, windowY, windowWidth, windowHeight, collapsed, bubbleX, bubbleY, layoutVersion
    }
}

private struct Snapshot: Codable {
    var settings: Settings
    var drinks: [DrinkEntry]
    var nextReminder: Date
    var lastAck: Date
}

final class AppModel: ObservableObject {
    @Published var settings: Settings
    @Published var drinks: [DrinkEntry]
    @Published var nextReminder: Date
    @Published var isReminding = false
    @Published var alertFlash = false

    var lastAck: Date
    var lastSoundAt: Date?
    var soundHook: ((String) -> Void)?
    var onOrderFront: (() -> Void)?
    var onReveal: (() -> Void)?
    var onAlert: (() -> Void)?
    var onStatus: (() -> Void)?

    let storeURL: URL

    private var timer: Timer?
    private var previewToken = 0

    static let defaultStoreURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WaterReminder/data.json")
    }()

    static let soundCatalog: [SoundOption] = [
        SoundOption(name: "Glass", title: "玻璃杯"),
        SoundOption(name: "Ping", title: "清脆"),
        SoundOption(name: "Pop", title: "轻弹"),
        SoundOption(name: "Tink", title: "叮当"),
        SoundOption(name: "Bottle", title: "玻璃瓶"),
        SoundOption(name: "Frog", title: "蛙鸣"),
        SoundOption(name: "Funk", title: "鼓点"),
        SoundOption(name: "Hero", title: "号角"),
        SoundOption(name: "Submarine", title: "声纳"),
        SoundOption(name: "Purr", title: "猫喘"),
        SoundOption(name: "Blow", title: "吹哨"),
        SoundOption(name: "Basso", title: "低沉"),
        SoundOption(name: "Sosumi", title: "经典"),
        SoundOption(name: "Morse", title: "摩尔斯")
    ]

    init(storeURL: URL? = nil, startTimer: Bool = true) {
        self.storeURL = storeURL ?? Self.defaultStoreURL
        let now = Date()
        let initial = Settings()
        settings = initial
        drinks = []
        lastAck = now
        nextReminder = now.addingTimeInterval(TimeInterval(initial.intervalMinutes * 60))
        load()
        if startTimer {
            startLoop()
        }
    }

    var availableSounds: [SoundOption] {
        Self.soundCatalog.filter { NSSound(named: NSSound.Name($0.name)) != nil }
    }

    var reminderMessage: String {
        let text = settings.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "该喝水啦" : text
    }

    var goalProgress: Double {
        guard settings.dailyGoalMl > 0 else { return 0 }
        return min(1, Double(mlToday()) / Double(settings.dailyGoalMl))
    }

    func goalPercent(now: Date = Date()) -> Int {
        guard settings.dailyGoalMl > 0 else { return 0 }
        return Int((Double(ml(on: now)) / Double(settings.dailyGoalMl) * 100).rounded())
    }

    func mlToday(now: Date = Date()) -> Int { ml(on: now) }
    func countToday(now: Date = Date()) -> Int { count(on: now) }

    func ml(on day: Date, calendar: Calendar = .current) -> Int {
        drinks(on: day, calendar: calendar).reduce(0) { $0 + $1.ml }
    }

    func count(on day: Date, calendar: Calendar = .current) -> Int {
        drinks(on: day, calendar: calendar).count
    }

    func drinks(on day: Date, calendar: Calendar = .current) -> [DrinkEntry] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return drinks
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
    }

    func drinksToday(now: Date = Date()) -> [DrinkEntry] {
        drinks(on: now).sorted { $0.date > $1.date }
    }

    func averageGapMinutes(on day: Date = Date(), calendar: Calendar = .current) -> Int? {
        let times = drinks(on: day, calendar: calendar).map(\.date).sorted()
        guard times.count >= 2 else { return nil }
        let total = zip(times, times.dropFirst()).reduce(0.0) { partial, pair in
            partial + pair.1.timeIntervalSince(pair.0)
        }
        return Int((total / Double(times.count - 1) / 60).rounded())
    }

    func averageGapMinutesToday(now: Date = Date()) -> Int? {
        averageGapMinutes(on: now)
    }

    func recentDays(_ count: Int = 7, now: Date = Date(), calendar: Calendar = .current) -> [DayStat] {
        let today = calendar.startOfDay(for: now)
        var result: [DayStat] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let end = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
            let items = drinks.filter { $0.date >= day && $0.date < end }
            result.append(DayStat(
                id: day,
                label: shortDayLabel(day, now: now, calendar: calendar),
                count: items.count,
                ml: items.reduce(0) { $0 + $1.ml }
            ))
        }
        return result
    }

    /// 按 7 天一块汇总，从今天往前覆盖 `coveringDays` 天。
    func recentWeeks(coveringDays: Int, now: Date = Date(), calendar: Calendar = .current) -> [DayStat] {
        let today = calendar.startOfDay(for: now)
        let weekCount = max(1, Int(ceil(Double(coveringDays) / 7.0)))
        var result: [DayStat] = []
        for weekIndex in 0..<weekCount {
            let endOffset = (weekCount - 1 - weekIndex) * 7
            let startOffset = endOffset + 6
            guard let start = calendar.date(byAdding: .day, value: -startOffset, to: today),
                  let end = calendar.date(byAdding: .day, value: 1 - endOffset, to: today) else { continue }
            let items = drinks.filter { $0.date >= start && $0.date < end }
            result.append(DayStat(
                id: start,
                label: Self.dayFormatter.string(from: start),
                count: items.count,
                ml: items.reduce(0) { $0 + $1.ml }
            ))
        }
        return result
    }

    func chartBuckets(lastDays: Int, now: Date = Date()) -> [DayStat] {
        lastDays > 31 ? recentWeeks(coveringDays: lastDays, now: now) : recentDays(lastDays, now: now)
    }

    func summary(lastDays: Int, now: Date = Date()) -> (count: Int, ml: Int) {
        let days = recentDays(lastDays, now: now)
        return (days.reduce(0) { $0 + $1.count }, days.reduce(0) { $0 + $1.ml })
    }

    func frequencyText(now: Date = Date()) -> String {
        let count = count(on: now)
        if count == 0 { return "今天还没有记录" }
        if let gap = averageGapMinutes(on: now) {
            return "今日 \(count) 次 · 约 \(gap) 分钟一杯"
        }
        return "今日 \(count) 次"
    }

    func todayNarrative(now: Date = Date()) -> String {
        let count = count(on: now)
        let amount = ml(on: now)
        if count == 0 {
            return "今天还没有喝水。记一杯之后，这里会统计次数、间隔和总量。"
        }
        if let gap = averageGapMinutes(on: now) {
            return "今天喝了 \(count) 次，共 \(amount) ml，平均每隔 \(gap) 分钟喝一次。"
        }
        return "今天喝了 \(count) 次，共 \(amount) ml。再记一杯就能算出平均间隔。"
    }

    func weekSummary(now: Date = Date()) -> String {
        rangeSummary(lastDays: 7, now: now)
    }

    func rangeSummary(lastDays: Int, now: Date = Date()) -> String {
        let days = max(1, lastDays)
        let total = summary(lastDays: days, now: now)
        let average = Double(total.count) / Double(days)
        return "近 \(days) 日共 \(total.count) 次、\(total.ml) ml，日均 \(String(format: "%.1f", average)) 次"
    }

    var yearSummary: String {
        let amount = drinks.reduce(0) { $0 + $1.ml }
        return "近一年累计 \(drinks.count) 次 · \(amount) ml"
    }

    func menuSummary() -> String {
        "今日 \(mlToday()) ml · \(countToday()) 次"
    }

    func statusText(now: Date = Date()) -> String {
        if settings.paused {
            return "喝水提醒已暂停 · 今日 \(mlToday()) ml"
        }
        if isReminding {
            return reminderMessage
        }
        return "下次 \(clock(nextReminder)) · \(remainingText(from: now))"
    }

    func clock(_ date: Date) -> String {
        Self.hourFormatter.string(from: date)
    }

    func remainingText(from now: Date = Date()) -> String {
        let seconds = Int(nextReminder.timeIntervalSince(now).rounded())
        if seconds <= 0 { return "就是现在" }
        if seconds < 60 { return "\(seconds) 秒后" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) 分钟后" }
        let hours = minutes / 60
        let remain = minutes % 60
        if remain == 0 { return "\(hours) 小时后" }
        return "\(hours) 小时 \(remain) 分钟后"
    }

    func setInterval(_ minutes: Int) {
        settings.intervalMinutes = min(240, max(1, minutes))
        nextReminder = lastAck.addingTimeInterval(TimeInterval(settings.intervalMinutes * 60))
        if nextReminder > Date() {
            isReminding = false
            alertFlash = false
        }
        save()
        evaluateReminder()
    }

    func setMessage(_ text: String) {
        settings.message = String(text.prefix(40))
        save()
        publishStatus()
    }

    func setColor(_ hex: String) {
        guard let normalized = NSColor(hex: hex)?.hexString else { return }
        guard normalized != settings.colorHex else { return }
        settings.colorHex = normalized
        save()
    }

    func setSound(_ name: String) {
        settings.soundName = name
        save()
    }

    func setCup(_ ml: Int) {
        let next = min(2000, max(50, ml))
        guard next != settings.cupMl else { return }
        settings.cupMl = next
        save()
    }

    func setGoal(_ ml: Int) {
        let next = min(10000, max(100, ml))
        guard next != settings.dailyGoalMl else { return }
        settings.dailyGoalMl = next
        save()
    }

    func setPaused(_ paused: Bool) {
        guard settings.paused != paused else { return }
        settings.paused = paused
        if paused {
            isReminding = false
            alertFlash = false
        }
        save()
        evaluateReminder()
    }

    func setExpandedFrame(_ frame: NSRect) {
        settings.windowX = Double(frame.origin.x)
        settings.windowY = Double(frame.origin.y)
        settings.windowWidth = Double(frame.width)
        settings.windowHeight = Double(frame.height)
        settings.layoutVersion = 2
        save()
    }

    func setBubbleOrigin(x: Double, y: Double) {
        settings.bubbleX = x
        settings.bubbleY = y
        save()
    }

    func setCollapsed(_ collapsed: Bool) {
        guard settings.collapsed != collapsed else { return }
        settings.collapsed = collapsed
        save()
    }

    func logDrink(ml: Int? = nil, at date: Date = Date(), resetsReminder: Bool = true) {
        let amount = min(2000, max(1, ml ?? settings.cupMl))
        drinks.append(DrinkEntry(id: UUID(), date: date, ml: amount))
        _ = pruneOldDrinks()
        if resetsReminder {
            lastAck = date
            nextReminder = date.addingTimeInterval(TimeInterval(settings.intervalMinutes * 60))
            if nextReminder > Date() {
                isReminding = false
                alertFlash = false
            }
        }
        save()
        evaluateReminder()
    }

    func deleteDrink(id: UUID) {
        drinks.removeAll { $0.id == id }
        save()
    }

    func snooze(minutes: Int) {
        let clamped = min(180, max(1, minutes))
        nextReminder = Date().addingTimeInterval(TimeInterval(clamped * 60))
        isReminding = false
        alertFlash = false
        save()
        evaluateReminder()
    }

    func skipReminder() {
        let now = Date()
        lastAck = now
        nextReminder = now.addingTimeInterval(TimeInterval(settings.intervalMinutes * 60))
        isReminding = false
        alertFlash = false
        save()
        evaluateReminder()
    }

    func previewReminder() {
        alertFlash = true
        playSound()
        onReveal?()
        publishStatus()
        previewToken += 1
        let token = previewToken
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard token == self.previewToken, !self.isReminding else { return }
            self.alertFlash = false
        }
    }

    func evaluateReminder(now: Date = Date()) {
        if settings.paused {
            if isReminding || alertFlash {
                isReminding = false
                alertFlash = false
                save()
            }
            publishStatus()
            return
        }

        if now >= nextReminder {
            if !isReminding {
                isReminding = true
                save()
                playSound()
                lastSoundAt = now
                onReveal?()
                onAlert?()
            } else if now.timeIntervalSince(lastSoundAt ?? .distantPast) >= 60 {
                playSound()
                lastSoundAt = now
                onOrderFront?()
            }
        }
        publishStatus()
    }

    func playSound() {
        let name = settings.soundName
        if let soundHook {
            soundHook(name)
            return
        }
        guard !name.isEmpty, let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.stop()
        sound.play()
    }

    func save() {
        do {
            let directory = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let snapshot = Snapshot(
                settings: settings,
                drinks: drinks,
                nextReminder: nextReminder,
                lastAck: lastAck
            )
            let data = try Self.encoder().encode(snapshot)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            NSLog("喝水提醒保存失败: \(error.localizedDescription)")
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }
        do {
            let data = try Data(contentsOf: storeURL)
            let snapshot = try Self.decoder().decode(Snapshot.self, from: data)
            settings = snapshot.settings.clamped()
            drinks = snapshot.drinks
            nextReminder = snapshot.nextReminder
            lastAck = snapshot.lastAck
            let soundBefore = settings.soundName
            normalizeSound()
            let removed = pruneOldDrinks()
            if settings.soundName != soundBefore || removed {
                save()
            }
        } catch {
            NSLog("喝水提醒读取失败，将使用默认设置: \(error.localizedDescription)")
            let backup = storeURL.deletingPathExtension().appendingPathExtension("bad.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: storeURL, to: backup)
        }
    }

    private func normalizeSound() {
        guard !settings.soundName.isEmpty else { return }
        if NSSound(named: NSSound.Name(settings.soundName)) == nil {
            settings.soundName = NSSound(named: NSSound.Name("Glass")) == nil ? "" : "Glass"
        }
    }

    @discardableResult
    private func pruneOldDrinks() -> Bool {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -400, to: Date()) else { return false }
        let before = drinks.count
        drinks.removeAll { $0.date < cutoff }
        return drinks.count != before
    }

    private func startLoop() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.evaluateReminder()
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func publishStatus() {
        onStatus?()
    }

    private func shortDayLabel(_ day: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "今天" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return "昨天"
        }
        return Self.dayFormatter.string(from: day)
    }

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
