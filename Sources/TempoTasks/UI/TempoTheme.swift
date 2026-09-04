import Foundation
import SwiftUI

/// OKLCH 转 sRGB。
///
/// OKLCH 在感知上均匀：等量的亮度变化看起来才是等量的，HSL 做不到这点。
/// 整套 token 用 OKLCH 定义，调色时只改这里的三个数，不必手工推 hex。
///
/// - Parameters:
///   - l: 亮度 0...1
///   - c: 色度，约 0...0.4
///   - h: 色相 0...360
func oklch(_ l: Double, _ c: Double, _ h: Double) -> Color {
    let hRad = h * .pi / 180
    let a = c * cos(hRad)
    let b = c * sin(hRad)

    let lPrime = l + 0.3963377774 * a + 0.2158037573 * b
    let mPrime = l - 0.1055613458 * a - 0.0638541728 * b
    let sPrime = l - 0.0894841775 * a - 1.2914855480 * b

    let lCubed = lPrime * lPrime * lPrime
    let mCubed = mPrime * mPrime * mPrime
    let sCubed = sPrime * sPrime * sPrime

    let red = 4.0767416621 * lCubed - 3.3077115913 * mCubed + 0.2309699292 * sCubed
    let green = -1.2684380046 * lCubed + 2.6097574011 * mCubed - 0.3413193965 * sCubed
    let blue = -0.0041960863 * lCubed - 0.7034186147 * mCubed + 1.7076147010 * sCubed

    func encode(_ value: Double) -> Double {
        let clamped = max(0, min(1, value))
        return clamped <= 0.0031308
            ? 12.92 * clamped
            : 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }

    return Color(.sRGB, red: encode(red), green: encode(green), blue: encode(blue))
}

/// TempoTasks 的设计 token。
///
/// 锚点是夜间飞行仪表盘，借它三件事：
/// 1. 亮度即优先级。逾期越久文字越亮，不用红色报警表达时间压力。
/// 2. 航空语义色序。绿表示正常与当前，琥珀表示注意，红只留给告警。
/// 3. 分组靠留白，不靠线框。
///
/// 所有中性色统一微偏 `accentHue`，避免出现死灰。
enum TempoTheme {
    /// 青绿。避开了蓝（250）和暖橙（60）这两个 AI 设计里最常见的默认色相，
    /// 同时对应仪表盘里「正常 / 当前」的绿。
    static let accentHue: Double = 165

    // MARK: - 表面
    //
    // 暗色下的深度来自表面亮度，不是阴影。三级台阶。

    static let canvas = oklch(0.145, 0.004, accentHue)
    static let surface = oklch(0.185, 0.005, accentHue)
    static let raised = oklch(0.235, 0.006, accentHue)
    static let raisedHover = oklch(0.285, 0.007, accentHue)

    /// 悬停时的极轻提亮，用显式颜色而不是白色叠透明度。
    static let rowHover = oklch(0.205, 0.005, accentHue)

    // MARK: - 文字
    //
    // 四级亮度就是四级优先级，这是整套设计的主线。

    /// 欠了很久的任务。
    static let textUrgent = oklch(0.95, 0.005, accentHue)
    static let textPrimary = oklch(0.86, 0.006, accentHue)
    static let textSecondary = oklch(0.62, 0.008, accentHue)
    /// 已完成，沉到最暗；完成的事应该退场，不该抢注意力。
    static let textDim = oklch(0.44, 0.006, accentHue)

    // MARK: - 语义色

    /// 焦点与当前选中。整个界面里唯一常驻的彩色，占比控制在 10% 以内。
    static let accent = oklch(0.76, 0.13, accentHue)
    static let accentMuted = oklch(0.34, 0.055, accentHue)
    static let accentSurface = oklch(0.24, 0.03, accentHue)

    /// 注意级。只在欠了很久时作为亮度之外的第二信号，不是警告。
    static let caution = oklch(0.80, 0.12, 75)

    /// 告警级。只给真正的错误，不再用于表示「完成」。
    static let alert = oklch(0.68, 0.19, 25)
    static let alertSurface = oklch(0.24, 0.05, 25)

    // MARK: - 描边

    static let hairline = oklch(0.26, 0.005, accentHue)
    static let border = oklch(0.32, 0.006, accentHue)

    // MARK: - 间距

    /// 4 pt 网格。
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let control: CGFloat = 8
        static let row: CGFloat = 10
        static let panel: CGFloat = 18
    }

    enum FontSize {
        static let display: CGFloat = 24
        static let title: CGFloat = 15
        static let body: CGFloat = 14
        static let label: CGFloat = 12
        static let caption: CGFloat = 11
        static let micro: CGFloat = 10
        static let dayNumber: CGFloat = 18
    }

    /// DESIGN.md 第 9 节：常规 UI 动效不超过 200ms，不使用弹簧与位移。
    enum Motion {
        static let quick: Double = 0.11
        static let standard: Double = 0.16
    }

    // MARK: - 时间的重量

    /// 逾期天数映射到文字亮度。
    /// 这是「逾期要可见但不惩罚」的落地方式：越久越亮，而不是越久越红。
    static func urgencyText(daysOverdue: Int) -> Color {
        switch daysOverdue {
        case 7...: textUrgent
        case 1...: textPrimary
        default: textSecondary
        }
    }

    /// 只有欠得实在久了才追加颜色作为第二信号，满足「不能只靠颜色传达状态」。
    static func urgencyAccent(daysOverdue: Int) -> Color? {
        daysOverdue >= 7 ? caution : nil
    }
}

// MARK: - 复用样式

/// 分组小标题。像仪表盘上的刻度标签：小、暗、退到背景里。
///
/// 不用等宽：这些标签是中文，等宽会把方块字的字距强行拉散。
/// DESIGN.md 第 3 节的规则是等宽只给日期数字和快捷键。
struct TempoSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: TempoTheme.FontSize.micro, weight: .medium))
            .tracking(0.4)
            .foregroundStyle(TempoTheme.textDim)
    }
}

/// 等宽快捷键帽。
struct TempoKeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: TempoTheme.FontSize.micro, weight: .semibold, design: .monospaced))
            .foregroundStyle(TempoTheme.textSecondary)
            .padding(.horizontal, TempoTheme.Space.xs + 1)
            .frame(height: TempoTheme.Space.lg)
            .background(TempoTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous))
    }
}

/// 按下时轻微降低不透明度，不做缩放位移。
struct TempoPressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick),
                value: configuration.isPressed
            )
    }
}

extension Notification.Name {
    static let tempoFocusInput = Notification.Name("TempoTasks.focusInput")
}
