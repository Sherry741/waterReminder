import AppKit
import QuartzCore
import SwiftUI

/// 悬浮在所有桌面之上，点击时不把当前正在用的应用切走。
final class WidgetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown, !isKeyWindow {
            makeKey()
        }
        super.sendEvent(event)
    }
}

final class ClearHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = AppModel()
    private var panel: WidgetPanel?
    private var settingsWindow: NSWindow?
    private var statsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var resizeBorder: ResizeBorderView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.onOrderFront = { [weak self] in
            self?.panel?.orderFrontRegardless()
        }
        model.onReveal = { [weak self] in
            self?.expandWidget()
            self?.panel?.orderFrontRegardless()
        }
        model.onAlert = { [weak self] in
            NSApp.requestUserAttention(.informationalRequest)
            ReminderNotifier.shared.sendReminder(message: self?.model.reminderMessage ?? "该喝水啦")
        }
        model.onStatus = { [weak self] in
            self?.refreshStatusItem()
        }

        ReminderNotifier.shared.configure()
        ReminderNotifier.shared.onOpen = { [weak self] in
            self?.expandWidget()
            self?.panel?.orderFrontRegardless()
            NSApp.activate()
        }

        installDockIcon()
        installMainMenu()
        installStatusItem()
        installWidget()
        model.evaluateReminder()
        panel?.orderFrontRegardless()
        saveWidgetFrame()
        NSApp.activate()
        if !UserDefaults.standard.bool(forKey: ReminderNotifier.onboardingKey) {
            openOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        resizeBorder?.stopHoverTracking()
        model.stop()
        model.save()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel?.orderFrontRegardless()
        return true
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusItem?.menu else { return }
        menu.removeAllItems()

        let summary = NSMenuItem(title: model.menuSummary(), action: nil, keyEquivalent: "")
        summary.isEnabled = false
        menu.addItem(summary)

        let status = NSMenuItem(title: model.statusText(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        addStatusItem(menu, "记一杯（\(model.settings.cupMl) ml）", #selector(logCup))
        addStatusItem(menu, model.settings.paused ? "继续提醒" : "暂停提醒", #selector(togglePause))
        addStatusItem(menu, "显示悬浮窗", #selector(showFloating))
        menu.addItem(.separator())
        addStatusItem(menu, "统计…", #selector(openStats))
        addStatusItem(menu, "设置…", #selector(openSettings))
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 waterReminder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)
    }

    private func installWidget() {
        let root = FloatingRootView(
            onDragEnd: { [weak self] in self?.saveWidgetFrame() },
            onOpenSettings: { [weak self] in self?.openSettings() },
            onOpenStats: { [weak self] in self?.openStats() },
            onMinimize: { [weak self] in self?.collapseWidget() },
            onExpand: { [weak self] in self?.expandWidget() }
        ).environmentObject(model)

        let host = ClearHostingView(rootView: root)
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor

        let border = ResizeBorderView()
        let side = Metrics.windowSide(on: NSScreen.main)
        border.minSize = NSSize(width: side, height: side)
        border.maxSize = Metrics.maxWidget
        border.isEnabled = !model.settings.collapsed
        border.onResizeEnd = { [weak self] in self?.saveWidgetFrame() }
        resizeBorder = border

        let panel = WidgetPanel(
            contentRect: currentFrame(),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "waterReminder"
        panel.acceptsMouseMovedEvents = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.minSize = NSSize(width: Metrics.bubble, height: Metrics.bubble)
        panel.maxSize = Metrics.maxWidget
        panel.isMovable = true
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.becomesKeyOnlyIfNeeded = true
        let container = NSView(frame: NSRect(origin: .zero, size: currentFrame().size))
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        border.frame = container.bounds
        border.autoresizingMask = [.width, .height]
        container.addSubview(host)
        container.addSubview(border)
        panel.contentView = container
        panel.setFrame(currentFrame(), display: false)
        border.startHoverTracking()
        self.panel = panel
    }

    private func currentFrame() -> NSRect {
        model.settings.collapsed ? bubbleFrame() : expandedFrame()
    }

    private func expandedFrame() -> NSRect {
        let screen = NSScreen.main
        let compact = Metrics.windowSide(on: screen)
        let minimum = NSSize(width: compact, height: compact)
        let useSavedSize = model.settings.layoutVersion >= 2
        let width = min(
            Metrics.maxWidget.width,
            max(minimum.width, useSavedSize ? (model.settings.windowWidth ?? compact) : compact)
        )
        let height = min(
            Metrics.maxWidget.height,
            max(minimum.height, useSavedSize ? (model.settings.windowHeight ?? compact) : compact)
        )
        let size = NSSize(width: width, height: height)
        if let x = model.settings.windowX, let y = model.settings.windowY {
            let rect = NSRect(x: x, y: y, width: size.width, height: size.height)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(rect.insetBy(dx: 20, dy: 20)) }) {
                return clampToScreen(rect)
            }
        }
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        return NSRect(
            x: visible.maxX - size.width - 28,
            y: visible.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func bubbleFrame() -> NSRect {
        let side = Metrics.bubble
        if let x = model.settings.bubbleX, let y = model.settings.bubbleY {
            let rect = NSRect(x: x, y: y, width: side, height: side)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(rect) }) {
                return rect
            }
        }
        let expanded = expandedFrame()
        return NSRect(x: expanded.maxX - side, y: expanded.maxY - side, width: side, height: side)
    }

    private func clampToScreen(_ frame: NSRect) -> NSRect {
        guard let screen = panel?.screen ?? NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) ?? NSScreen.main else {
            return frame
        }
        let visible = screen.visibleFrame
        var next = frame
        next.size.width = min(next.width, visible.width)
        next.size.height = min(next.height, visible.height)
        if next.maxX > visible.maxX { next.origin.x = visible.maxX - next.width }
        if next.minX < visible.minX { next.origin.x = visible.minX }
        if next.maxY > visible.maxY { next.origin.y = visible.maxY - next.height }
        if next.minY < visible.minY { next.origin.y = visible.minY }
        return next
    }

    private func collapseWidget() {
        guard let panel, !model.settings.collapsed else { return }
        resizeBorder?.isEnabled = false
        let expanded = panel.frame
        model.setExpandedFrame(expanded)
        model.setCollapsed(true)
        let side = Metrics.bubble
        let target = clampToScreen(NSRect(
            x: expanded.maxX - side,
            y: expanded.maxY - side,
            width: side,
            height: side
        ))
        animate(panel, to: target) { [weak self] in
            guard let self, self.model.settings.collapsed else { return }
            self.model.setBubbleOrigin(x: target.origin.x, y: target.origin.y)
        }
    }

    private func expandWidget() {
        guard let panel, model.settings.collapsed else { return }
        let bubble = panel.frame
        var restored = expandedFrame()
        let side = Metrics.bubble
        restored.origin.x += bubble.origin.x - (restored.maxX - side)
        restored.origin.y += bubble.origin.y - (restored.maxY - side)
        restored = clampToScreen(restored)
        resizeBorder?.isEnabled = true
        model.setCollapsed(false)
        animate(panel, to: restored) { [weak self] in
            guard let self, !self.model.settings.collapsed else { return }
            self.model.setExpandedFrame(restored)
        }
    }

    private func animate(_ panel: NSPanel, to frame: NSRect, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        } completionHandler: {
            completion?()
        }
    }

    private func saveWidgetFrame() {
        guard let panel else { return }
        if model.settings.collapsed {
            model.setBubbleOrigin(x: Double(panel.frame.origin.x), y: Double(panel.frame.origin.y))
        } else {
            model.setExpandedFrame(panel.frame)
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "waterReminder") {
            image.isTemplate = true
            item.button?.image = image
        }
        item.button?.toolTip = "waterReminder"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        refreshStatusItem()
    }

    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }
        button.toolTip = model.statusText()
        button.title = model.isReminding ? " 喝水" : ""
    }

    private func installMainMenu() {
        let root = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.title = "waterReminder"
        root.addItem(appMenuItem)

        let appMenu = NSMenu(title: "waterReminder")
        appMenuItem.submenu = appMenu

        let about = NSMenuItem(title: "关于 waterReminder", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())

        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)

        let permissions = NSMenuItem(title: "打开权限…", action: #selector(openOnboarding), keyEquivalent: "")
        permissions.target = self
        appMenu.addItem(permissions)

        let stats = NSMenuItem(title: "统计…", action: #selector(openStats), keyEquivalent: "s")
        stats.target = self
        appMenu.addItem(stats)

        let drink = NSMenuItem(title: "记一杯", action: #selector(logCup), keyEquivalent: "d")
        drink.target = self
        appMenu.addItem(drink)

        let pause = NSMenuItem(title: "暂停/继续提醒", action: #selector(togglePause), keyEquivalent: "p")
        pause.target = self
        appMenu.addItem(pause)
        appMenu.addItem(.separator())

        let quit = NSMenuItem(title: "退出 waterReminder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        appMenu.addItem(quit)

        NSApp.mainMenu = root
    }

    private func installDockIcon() {
        let image = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { rect in
            let bounds = rect.insetBy(dx: 48, dy: 48)
            let background = NSBezierPath(roundedRect: bounds, xRadius: 220, yRadius: 220)
            NSColor(srgbRed: 0.18, green: 0.61, blue: 1, alpha: 1).setFill()
            background.fill()

            let drop = NSBezierPath()
            drop.move(to: NSPoint(x: 512, y: 780))
            drop.curve(
                to: NSPoint(x: 300, y: 470),
                controlPoint1: NSPoint(x: 512, y: 780),
                controlPoint2: NSPoint(x: 300, y: 650)
            )
            drop.curve(
                to: NSPoint(x: 512, y: 270),
                controlPoint1: NSPoint(x: 300, y: 330),
                controlPoint2: NSPoint(x: 390, y: 270)
            )
            drop.curve(
                to: NSPoint(x: 724, y: 470),
                controlPoint1: NSPoint(x: 634, y: 270),
                controlPoint2: NSPoint(x: 724, y: 330)
            )
            drop.curve(
                to: NSPoint(x: 512, y: 780),
                controlPoint1: NSPoint(x: 724, y: 650),
                controlPoint2: NSPoint(x: 512, y: 780)
            )
            drop.close()
            NSColor.white.setFill()
            drop.fill()
            return true
        }
        NSApp.applicationIconImage = image
    }

    private func addStatusItem(_ menu: NSMenu, _ title: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func logCup() {
        model.logDrink()
        panel?.orderFrontRegardless()
    }

    @objc private func togglePause() {
        model.setPaused(!model.settings.paused)
    }

    @objc private func showFloating() {
        expandWidget()
        panel?.orderFrontRegardless()
    }

    @objc private func openOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = makeAuxWindow(
                title: "打开权限",
                size: NSSize(width: 460, height: 420),
                view: OnboardingView { [weak self] in
                    self?.onboardingWindow?.close()
                }
            )
        }
        present(onboardingWindow)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = makeAuxWindow(
                title: "提醒设置",
                size: Metrics.settings,
                view: SettingsView().environmentObject(model)
            )
        }
        present(settingsWindow)
    }

    @objc private func openStats() {
        if statsWindow == nil {
            statsWindow = makeAuxWindow(
                title: "喝水统计",
                size: Metrics.stats,
                view: StatsView().environmentObject(model)
            )
        }
        present(statsWindow)
    }

    @objc private func showAbout() {
        NSApp.activate()
        let credits = NSAttributedString(
            string: "悬浮在桌面上，按你设置的间隔提醒喝水，并统计次数和饮水量。",
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "waterReminder",
            .credits: credits
        ])
    }

    private func makeAuxWindow<V: View>(title: String, size: NSSize, view: V) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        let host = NSHostingView(rootView: view)
        window.contentView = host
        window.setContentSize(size)
        return window
    }

    private func present(_ window: NSWindow?) {
        guard let window else { return }
        if !window.isVisible {
            placeNearWidget(window)
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func placeNearWidget(_ window: NSWindow) {
        guard let panel, let screen = panel.screen ?? NSScreen.main else {
            window.center()
            return
        }
        let size = window.frame.size
        let visible = screen.visibleFrame
        let widget = panel.frame
        var x = widget.minX - size.width - 12
        var y = widget.maxY - size.height
        if x < visible.minX {
            x = min(widget.maxX + 12, visible.maxX - size.width - 12)
        }
        if x + size.width > visible.maxX {
            x = visible.maxX - size.width - 12
        }
        if x < visible.minX {
            x = visible.minX + 12
        }
        if y < visible.minY {
            y = visible.minY + 12
        }
        if y + size.height > visible.maxY {
            y = visible.maxY - size.height - 12
        }
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
