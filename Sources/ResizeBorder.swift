import AppKit

/// 盖在悬浮窗最上层。只有鼠标靠近卡片边框时才接手，用来改光标和拖拽缩放。
final class ResizeBorderView: NSView {
    struct Edge: OptionSet {
        let rawValue: Int
        static let top = Edge(rawValue: 1 << 0)
        static let bottom = Edge(rawValue: 1 << 1)
        static let left = Edge(rawValue: 1 << 2)
        static let right = Edge(rawValue: 1 << 3)
    }

    var isEnabled = true
    var minSize = Metrics.fallbackWindow
    var maxSize = Metrics.maxWidget
    var onResizeEnd: (() -> Void)?

    private var dragMonitor: Any?
    private var hoverMonitors: [Any] = []
    private var showingResizeCursor = false
    private var startFrame: NSRect = .zero
    private var startMouse: NSPoint = .zero
    private var activeEdge: Edge = []

    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard isEnabled, !edge(at: local).isEmpty else { return nil }
        return self
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func cursorUpdate(with event: NSEvent) {
        refreshCursor(at: event.locationInWindow)
    }

    override func mouseMoved(with event: NSEvent) {
        refreshCursor(at: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        clearResizeCursor()
    }

    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        let edge = edge(at: local)
        guard isEnabled, !edge.isEmpty, let window else { return }
        activeEdge = edge
        startFrame = window.frame
        startMouse = NSEvent.mouseLocation
        Self.cursor(for: edge).set()
        showingResizeCursor = true
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.trackDrag(event)
            return event
        }
    }

    func startHoverTracking() {
        stopHoverTracking()
        let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.refreshCursor(atScreen: NSEvent.mouseLocation)
            return event
        }
        if let local {
            hoverMonitors.append(local)
        }
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.refreshCursor(atScreen: NSEvent.mouseLocation)
        }
        if let global {
            hoverMonitors.append(global)
        }
    }

    func stopHoverTracking() {
        hoverMonitors.forEach(NSEvent.removeMonitor)
        hoverMonitors.removeAll()
        endDrag()
    }

    private func trackDrag(_ event: NSEvent) {
        if event.type == .leftMouseUp {
            endDrag()
            onResizeEnd?()
            return
        }
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - startMouse.x
        let dy = mouse.y - startMouse.y
        var frame = startFrame

        if activeEdge.contains(.right) {
            frame.size.width = clamp(startFrame.width + dx, min: minSize.width, max: maxSize.width)
        }
        if activeEdge.contains(.left) {
            let width = clamp(startFrame.width - dx, min: minSize.width, max: maxSize.width)
            frame.size.width = width
            frame.origin.x = startFrame.maxX - width
        }
        if activeEdge.contains(.top) {
            frame.size.height = clamp(startFrame.height + dy, min: minSize.height, max: maxSize.height)
        }
        if activeEdge.contains(.bottom) {
            let height = clamp(startFrame.height - dy, min: minSize.height, max: maxSize.height)
            frame.size.height = height
            frame.origin.y = startFrame.maxY - height
        }
        window.setFrame(frame, display: true)
        Self.cursor(for: activeEdge).set()
    }

    private func endDrag() {
        if let dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
        }
        dragMonitor = nil
        activeEdge = []
    }

    private func refreshCursor(at locationInWindow: NSPoint) {
        guard let window else { return }
        let frame = window.frame
        refreshCursor(atScreen: NSPoint(x: frame.minX + locationInWindow.x, y: frame.minY + locationInWindow.y))
    }

    private func refreshCursor(atScreen mouse: NSPoint) {
        guard let window, window.isVisible, isEnabled else {
            clearResizeCursor()
            return
        }
        let frame = window.frame
        guard frame.contains(mouse) else {
            clearResizeCursor()
            return
        }
        let local = NSPoint(x: mouse.x - frame.minX, y: mouse.y - frame.minY)
        let edge = edge(at: local)
        if edge.isEmpty {
            clearResizeCursor()
            return
        }
        Self.cursor(for: edge).set()
        showingResizeCursor = true
    }

    private func clearResizeCursor() {
        guard showingResizeCursor else { return }
        NSCursor.arrow.set()
        showingResizeCursor = false
    }

    private func edge(at point: NSPoint) -> Edge {
        guard isEnabled, bounds.contains(point) else { return [] }
        let reach = Metrics.shadowInset + 6
        var edge: Edge = []
        if point.x <= bounds.minX + reach { edge.insert(.left) }
        if point.x >= bounds.maxX - reach { edge.insert(.right) }
        if point.y <= bounds.minY + reach { edge.insert(.bottom) }
        if point.y >= bounds.maxY - reach { edge.insert(.top) }
        return edge
    }

    private func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.min(upper, Swift.max(lower, value))
    }

    private static func cursor(for edge: Edge) -> NSCursor {
        guard #available(macOS 15.0, *) else {
            if edge.contains(.left) || edge.contains(.right), edge.contains(.top) || edge.contains(.bottom) {
                return .crosshair
            }
            if edge.contains(.left) || edge.contains(.right) { return .resizeLeftRight }
            return .resizeUpDown
        }
        let position: NSCursor.FrameResizePosition
        switch (edge.contains(.top), edge.contains(.bottom), edge.contains(.left), edge.contains(.right)) {
        case (true, _, true, _): position = .topLeft
        case (true, _, _, true): position = .topRight
        case (_, true, true, _): position = .bottomLeft
        case (_, true, _, true): position = .bottomRight
        case (true, _, _, _): position = .top
        case (_, true, _, _): position = .bottom
        case (_, _, true, _): position = .left
        default: position = .right
        }
        return .frameResize(position: position, directions: [.inward, .outward])
    }
}
