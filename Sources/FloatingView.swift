import AppKit
import SwiftUI

struct FloatingRootView: View {
    @EnvironmentObject private var model: AppModel
    var onDragEnd: () -> Void
    var onOpenSettings: () -> Void
    var onOpenStats: () -> Void
    var onMinimize: () -> Void
    var onExpand: () -> Void

    @State private var pulse = false

    private var alerting: Bool { model.isReminding || model.alertFlash }
    private var theme: Color {
        Color(hex: model.settings.colorHex) ?? Color(red: 0.18, green: 0.61, blue: 1)
    }
    private var onColor: Color {
        theme.prefersDarkText ? Color.black.opacity(0.88) : Color.white
    }
    private var ink: Color { alerting ? onColor : Color.primary }
    private var subInk: Color { alerting ? onColor.opacity(0.82) : Color.secondary }
    private var actionFill: Color {
        if alerting {
            return theme.prefersDarkText ? Color.black.opacity(0.82) : Color.white.opacity(0.95)
        }
        return theme
    }
    private var actionText: Color {
        if alerting {
            return theme.prefersDarkText ? Color.white : Color.black.opacity(0.88)
        }
        return theme.prefersDarkText ? Color.black.opacity(0.88) : Color.white
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if model.settings.collapsed {
                bubble
                    .padding(8)
            } else {
                expandedCard
                    .padding(Metrics.shadowInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            statusRow
            Spacer(minLength: 4)
            primaryButton
            bottomRow
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.20), radius: 8, y: 4)
    }

    private var bubble: some View {
        DragHandle(onDragEnd: onDragEnd, onClick: onExpand)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle()
                        .trim(from: 0, to: max(model.goalProgress, 0.02))
                        .stroke(
                            theme.opacity(alerting ? 0.95 : 0.7),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(3)
                    GlassCup(theme: theme, alerting: alerting)
                        .scaleEffect(alerting ? (pulse ? 1.06 : 0.96) : 1)
                        .padding(6)
                }
                .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(alerting ? 0.30 : 0.22), radius: alerting ? 12 : 8, y: 3)
            .help(model.isReminding ? "点击展开提醒" : "点击展开，拖动可移动")
            .accessibilityLabel("展开 waterReminder")
    }

    private var dropGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.opacity(0.95),
                theme,
                darker(theme, by: 0.18)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var header: some View {
        HStack(spacing: 6) {
            DragHandle(onDragEnd: onDragEnd)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(alerting ? onColor : theme)
                        Text("waterReminder")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(ink)
                            .lineLimit(1)
                    }
                    .allowsHitTesting(false)
                }
            iconButton(
                symbol: model.settings.paused ? "play.fill" : "pause.fill",
                help: model.settings.paused ? "继续提醒" : "暂停提醒"
            ) {
                model.setPaused(!model.settings.paused)
            }
            iconButton(symbol: "minus", help: "最小化成小圆", action: onMinimize)
        }
        .frame(height: 22)
    }

    private var statusRow: some View {
        info
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var info: some View {
        if model.isReminding || model.alertFlash {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.reminderMessage)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                Text(model.isReminding ? "点下面记下" : "预览")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(subInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if model.settings.paused {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(model.mlToday()) / \(model.settings.dailyGoalMl) ml")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("今日 \(model.countToday()) 次")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(subInk)
                    .lineLimit(1)
                Text("提醒已暂停")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(subInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.mlToday()) / \(model.settings.dailyGoalMl) ml")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("今日 \(model.countToday()) 次")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(subInk)
                        .lineLimit(1)
                    Text(model.remainingText(from: context.date))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(subInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var primaryButton: some View {
        Button(action: { model.logDrink() }) {
            Text(model.isReminding ? "喝了 \(model.settings.cupMl) ml" : "记一杯 \(model.settings.cupMl) ml")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(actionText)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(actionFill)
        )
        .help(model.isReminding ? "记录这一杯并开始下一轮计时" : "记录一杯水")
    }

    @ViewBuilder
    private var bottomRow: some View {
        if model.isReminding {
            HStack(spacing: 4) {
                snoozeButton(5)
                snoozeButton(10)
                snoozeButton(30)
                Spacer(minLength: 0)
                Button("跳过") { model.skipReminder() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(onColor.opacity(0.9))
                    .help("这次不记录，并开始下一轮计时")
            }
            .frame(height: 22)
        } else {
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    stepButton(symbol: "minus", help: "减少 50 ml") {
                        model.setCup(model.settings.cupMl - 50)
                    }
                    Text("\(model.settings.cupMl)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(ink)
                        .frame(width: 32)
                    stepButton(symbol: "plus", help: "增加 50 ml") {
                        model.setCup(model.settings.cupMl + 50)
                    }
                }
                Spacer(minLength: 0)
                iconButton(symbol: "chart.bar.fill", help: "统计", action: onOpenStats)
                iconButton(symbol: "gearshape.fill", help: "设置", action: onOpenSettings)
            }
            .frame(height: 22)
        }
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(alerting ? theme.opacity(pulse ? 0.98 : 0.84) : theme.opacity(0.18))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    alerting ? Color.white.opacity(0.45) : theme.opacity(0.75),
                    lineWidth: alerting ? 2.5 : 1.25
                )
        }
    }

    private func snoozeButton(_ minutes: Int) -> some View {
        Button("\(minutes)分") { model.snooze(minutes: minutes) }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .foregroundStyle(onColor)
            .background(Capsule().fill(onColor.opacity(0.16)))
            .help("\(minutes) 分钟后再提醒")
    }

    private func iconButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .background(Circle().fill(ink.opacity(0.12)))
        .help(help)
        .accessibilityLabel(help)
    }

    private func stepButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 18, height: 18)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .background(Circle().fill(ink.opacity(0.12)))
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct DragHandle: NSViewRepresentable {
    var onDragEnd: () -> Void
    var onClick: (() -> Void)? = nil

    func makeNSView(context: Context) -> DragNSView {
        let view = DragNSView()
        view.onDragEnd = onDragEnd
        view.onClick = onClick
        return view
    }

    func updateNSView(_ view: DragNSView, context: Context) {
        view.onDragEnd = onDragEnd
        view.onClick = onClick
        view.window?.invalidateCursorRects(for: view)
    }
}

private final class DragNSView: NSView {
    var onDragEnd: (() -> Void)?
    var onClick: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: onClick == nil ? .openHand : .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        let start = NSEvent.mouseLocation
        window?.performDrag(with: event)
        let end = NSEvent.mouseLocation
        let moved = hypot(end.x - start.x, end.y - start.y)
        if moved < 4, let onClick {
            onClick()
        } else {
            onDragEnd?()
        }
    }
}

/// 标准水滴形状：顶部尖、底部圆。
struct DropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let top = CGPoint(x: w * 0.5, y: 0)
        let bottomCenter = CGPoint(x: w * 0.5, y: h * 0.62)
        let radius = w * 0.42
        let right = CGPoint(x: bottomCenter.x + radius, y: bottomCenter.y)

        path.move(to: top)
        path.addCurve(
            to: right,
            control1: CGPoint(x: w * 0.5, y: h * 0.42),
            control2: CGPoint(x: w * 0.9, y: h * 0.42)
        )
        path.addArc(
            center: bottomCenter,
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: true
        )
        path.addCurve(
            to: top,
            control1: CGPoint(x: w * 0.1, y: h * 0.42),
            control2: CGPoint(x: w * 0.5, y: h * 0.42)
        )
        path.closeSubpath()
        return path
    }
}

/// 水杯形状：上宽下窄、圆底、带杯口。
struct CupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let topLeft = CGPoint(x: w * 0.17, y: h * 0.12)
        let topRight = CGPoint(x: w * 0.83, y: h * 0.12)
        let bottomRight = CGPoint(x: w * 0.74, y: h * 0.78)
        let bottomCenter = CGPoint(x: w * 0.5, y: h * 0.78)
        let bottomRadius = w * 0.24

        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addArc(
            center: bottomCenter,
            radius: bottomRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: true
        )
        path.addLine(to: topLeft)
        path.closeSubpath()
        return path
    }
}

/// 最小化时的「水杯装水」插画。
struct GlassCup: View {
    let theme: Color
    let alerting: Bool

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let left = w * 0.24
        let right = w * 0.76
        let top = h * 0.16
        let bottom = h * 0.86
        let midX = (left + right) / 2
        let topLeft = CGPoint(x: left, y: top)
        let topRight = CGPoint(x: right, y: top)
        let bottomLeft = CGPoint(x: left + w * 0.04, y: bottom - h * 0.10)
        let bottomRight = CGPoint(x: right - w * 0.04, y: bottom - h * 0.10)
        let bottomTip = CGPoint(x: midX, y: bottom)

        var glass = Path()
        glass.move(to: topLeft)
        glass.addLine(to: bottomLeft)
        glass.addQuadCurve(to: bottomTip, control: CGPoint(x: left + w * 0.06, y: bottom))
        glass.addQuadCurve(to: bottomRight, control: CGPoint(x: right - w * 0.06, y: bottom))
        glass.addLine(to: topRight)
        glass.closeSubpath()

        let waterTop = Color(red: 0.62, green: 0.86, blue: 1.0)
        let waterBottom = Color(red: 0.36, green: 0.68, blue: 0.98)
        context.fill(glass, with: .linearGradient(
            Gradient(colors: [waterTop, waterBottom]),
            startPoint: CGPoint(x: midX, y: top),
            endPoint: CGPoint(x: midX, y: bottom)))

        let rimRect = CGRect(x: left, y: top - h * 0.045, width: right - left, height: h * 0.09)
        context.fill(Path(ellipseIn: rimRect), with: .color(waterBottom))
        context.stroke(Path(ellipseIn: rimRect), with: .color(.white.opacity(0.85)), lineWidth: 1.5)
        let shineRect = CGRect(
            x: left + w * 0.06,
            y: top - h * 0.028,
            width: (right - left) * 0.38,
            height: h * 0.03
        )
        context.fill(Path(ellipseIn: shineRect), with: .color(.white.opacity(0.45)))

        var outline = Path()
        outline.move(to: topLeft)
        outline.addLine(to: bottomLeft)
        outline.addQuadCurve(to: bottomTip, control: CGPoint(x: left + w * 0.06, y: bottom))
        outline.addQuadCurve(to: bottomRight, control: CGPoint(x: right - w * 0.06, y: bottom))
        outline.addLine(to: topRight)
        context.stroke(outline, with: .color(.white.opacity(0.95)), lineWidth: 2)

        var highlight = Path()
        highlight.move(to: CGPoint(x: left + w * 0.05, y: top + h * 0.08))
        highlight.addLine(to: CGPoint(x: left + w * 0.08, y: bottom - h * 0.16))
        context.stroke(highlight, with: .color(.white.opacity(0.55)), lineWidth: 2)

        if alerting {
            context.stroke(outline, with: .color(theme.opacity(0.9)), lineWidth: 3)
            context.stroke(Path(ellipseIn: rimRect), with: .color(theme.opacity(0.9)), lineWidth: 2)
        }
    }
}

