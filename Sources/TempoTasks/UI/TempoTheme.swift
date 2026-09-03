import SwiftUI

/// TempoTasks 的设计 token。
///
/// 命名按职责而非外观：换配色时只改这里，调用处不动。
/// 职责边界见 DESIGN.md 第 2 节——`accent` 只表示交互焦点与当前选中，
/// `coral` 只表示完成与错误，两者不互换。品牌与装饰一律走中性色。
enum TempoTheme {
    // MARK: - 表面层级

    static let canvas = Color(red: 7 / 255, green: 8 / 255, blue: 10 / 255)
    static let surface = Color(red: 16 / 255, green: 17 / 255, blue: 17 / 255)
    static let raised = Color(red: 27 / 255, green: 28 / 255, blue: 30 / 255)
    static let raisedHover = Color(red: 36 / 255, green: 37 / 255, blue: 40 / 255)

    // MARK: - 文字

    static let primaryText = Color.white.opacity(0.88)
    static let secondaryText = Color.white.opacity(0.64)
    static let completedText = Color.white.opacity(0.38)

    // MARK: - 描边

    static let hairline = Color.white.opacity(0.06)
    static let strongBorder = Color.white.opacity(0.10)
    static let hoverBorder = Color.white.opacity(0.18)

    // MARK: - 语义色

    /// 交互焦点与当前选中。不表达状态好坏。
    static let focusBlue = Color(red: 85 / 255, green: 179 / 255, blue: 1)
    /// 完成与错误。
    static let completionCoral = Color(red: 1, green: 99 / 255, blue: 99 / 255)
    static let successGreen = Color(red: 95 / 255, green: 201 / 255, blue: 146 / 255)

    // MARK: - 间距

    /// 4 pt 网格。布局只允许取这些值，避免间距漂移成随机数。
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - 圆角

    enum Radius {
        static let sm: CGFloat = 6
        static let control: CGFloat = 8
        static let row: CGFloat = 10
        static let panel: CGFloat = 18
    }

    // MARK: - 字号

    enum FontSize {
        static let display: CGFloat = 22
        static let title: CGFloat = 15
        static let body: CGFloat = 14
        static let label: CGFloat = 12
        static let caption: CGFloat = 11
        static let micro: CGFloat = 10
        static let dayNumber: CGFloat = 19
    }

    // MARK: - 动效

    /// DESIGN.md 第 9 节：常规 UI 动效不超过 200ms，不使用弹簧与位移。
    enum Motion {
        static let quick: Double = 0.11
        static let standard: Double = 0.16
    }
}

// MARK: - 复用样式

/// 分组小标题：等宽、字距放宽、次要色。
struct TempoSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: TempoTheme.FontSize.micro, weight: .semibold, design: .monospaced))
            .tracking(1.3)
            .foregroundStyle(TempoTheme.secondaryText)
    }
}

/// 等宽快捷键帽。
struct TempoKeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: TempoTheme.FontSize.micro, weight: .semibold, design: .monospaced))
            .foregroundStyle(TempoTheme.secondaryText)
            .padding(.horizontal, TempoTheme.Space.xs + 1)
            .frame(height: TempoTheme.Space.lg)
            .background(TempoTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous)
                    .stroke(TempoTheme.hairline, lineWidth: 1)
            }
    }
}

/// 按下时轻微降低不透明度，不做缩放位移。
struct TempoPressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick),
                value: configuration.isPressed
            )
    }
}

extension Notification.Name {
    static let tempoFocusInput = Notification.Name("TempoTasks.focusInput")
}
