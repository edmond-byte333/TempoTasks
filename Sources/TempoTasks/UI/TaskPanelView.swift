import AppKit
import SwiftUI

private extension LocalDay {
    var displayDate: String { formatted(locale: LocalDay.displayLocale) }
    var displayWeekday: String { weekday(locale: LocalDay.displayLocale) }
}

struct TaskPanelView: View {
    @Bindable var viewModel: TaskPanelViewModel
    let onClose: () -> Void
    let onDragBegan: () -> Void
    let onDragEnded: (NSRect, NSRect) -> Void

    var body: some View {
        ZStack {
            TempoTheme.canvas
            RadialGradient(
                colors: [TempoTheme.focusBlue.opacity(0.035), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )

            HStack(spacing: 0) {
                DateRailView(
                    viewModel: viewModel,
                    onDragBegan: onDragBegan,
                    onDragEnded: onDragEnded
                )
                .frame(width: 164)

                Rectangle()
                    .fill(TempoTheme.hairline)
                    .frame(width: 1)

                VStack(spacing: 0) {
                    panelHeader
                    QuickAddView(viewModel: viewModel)
                    TaskListView(viewModel: viewModel)
                }
            }
        }
        .frame(width: 760, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.panel, style: .continuous)
                .stroke(TempoTheme.strongBorder, lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
        .onExitCommand(perform: onClose)
    }

    // MARK: - 头部

    /// 标题位放当前日期本身，而不是每次都一样的疑问句。
    /// 语气化的提问移到输入框 placeholder，那里才是它起作用的地方。
    private var panelHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: TempoTheme.Space.xs) {
                Text(viewModel.selectedDateLabel)
                    .font(.system(size: TempoTheme.FontSize.display, weight: .semibold))
                    .foregroundStyle(TempoTheme.primaryText)

                // 星期由左栏日期项承担，这里不重复。
                Text(viewModel.selectedDay.displayDate)
                    .font(.system(size: TempoTheme.FontSize.caption))
                    .foregroundStyle(TempoTheme.secondaryText)
            }

            Spacer()

            progressSummary
        }
        .padding(.horizontal, TempoTheme.Space.xl)
        .padding(.top, TempoTheme.Space.xl)
        .padding(.bottom, TempoTheme.Space.lg)
        .overlay {
            WindowDragSurface(
                onDragBegan: onDragBegan,
                onDragEnded: onDragEnded
            )
        }
    }

    private var progressSummary: some View {
        let total = viewModel.tasks.count
        let done = viewModel.completedCount
        let ratio = total == 0 ? 0 : CGFloat(done) / CGFloat(total)

        return VStack(alignment: .trailing, spacing: TempoTheme.Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: TempoTheme.Space.xs) {
                Text(done, format: .number)
                    .font(.system(size: TempoTheme.FontSize.title, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(TempoTheme.primaryText)
                    .contentTransition(.numericText())

                Text("/ \(total)")
                    .font(.system(size: TempoTheme.FontSize.caption, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(TempoTheme.secondaryText)

                Text("已完成")
                    .font(.system(size: TempoTheme.FontSize.caption))
                    .foregroundStyle(TempoTheme.secondaryText)
                    .padding(.leading, TempoTheme.Space.xs)
            }

            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(TempoTheme.completionCoral)
                    .frame(width: 84 * ratio)
            }
            .frame(width: 84, height: 3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("共 \(total) 个任务，已完成 \(done) 个")
    }
}

// MARK: - 左侧日期轨道

private struct DateRailView: View {
    @Bindable var viewModel: TaskPanelViewModel
    let onDragBegan: () -> Void
    let onDragEnded: (NSRect, NSRect) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandMark

            TempoSectionLabel(text: "日程")
                .padding(.horizontal, TempoTheme.Space.lg)
                .padding(.bottom, TempoTheme.Space.sm)

            dateButton(selection: .today, day: viewModel.today, title: "今天")
            dateButton(selection: .tomorrow, day: viewModel.tomorrow, title: "明天")
            customDateButton

            Spacer(minLength: TempoTheme.Space.lg)

            shortcutHints
        }
        .background(TempoTheme.surface.opacity(0.78))
    }

    /// 品牌标记走中性色：珊瑚红的职责是完成与错误，不做装饰。
    private var brandMark: some View {
        HStack(spacing: TempoTheme.Space.sm) {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous)
                .fill(TempoTheme.raised)
                .frame(width: 22, height: 22)
                .overlay {
                    RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous)
                        .stroke(TempoTheme.strongBorder, lineWidth: 1)
                }
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: TempoTheme.FontSize.caption, weight: .bold))
                        .foregroundStyle(TempoTheme.primaryText)
                }

            Text("Tempo")
                .font(.system(size: TempoTheme.FontSize.body, weight: .semibold))
                .foregroundStyle(TempoTheme.primaryText)
        }
        .padding(.horizontal, TempoTheme.Space.lg)
        .padding(.top, TempoTheme.Space.xl)
        .padding(.bottom, TempoTheme.Space.xl)
        .overlay {
            WindowDragSurface(
                onDragBegan: onDragBegan,
                onDragEnded: onDragEnded
            )
        }
    }

    /// 底部原本是与头部重复的进度条，换成快捷键说明，并让唤出键可以就地改。
    private var shortcutHints: some View {
        VStack(alignment: .leading, spacing: TempoTheme.Space.sm) {
            HStack(spacing: TempoTheme.Space.sm) {
                TempoSectionLabel(text: "快捷键")
                Spacer(minLength: 0)
                if viewModel.hotKeyCombo != .default {
                    resetHotKeyButton
                }
            }

            HotKeyRecorderView(
                combo: viewModel.hotKeyCombo,
                isConflicting: !viewModel.hotKeyAvailable,
                onChange: viewModel.updateHotKey
            )

            hintRow(key: "esc", label: "关闭面板")
        }
        .padding(.horizontal, TempoTheme.Space.lg)
        .padding(.bottom, TempoTheme.Space.lg)
    }

    private var resetHotKeyButton: some View {
        Button {
            viewModel.updateHotKey(.default)
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: TempoTheme.FontSize.micro, weight: .semibold))
                .foregroundStyle(TempoTheme.secondaryText)
                .frame(width: TempoTheme.Space.lg, height: TempoTheme.Space.lg)
                .contentShape(Rectangle())
        }
        .buttonStyle(TempoPressableButtonStyle())
        .help("恢复默认快捷键 \(HotKeyCombo.default.displayString)")
        .accessibilityLabel("恢复默认快捷键")
    }

    private func hintRow(key: String, label: String) -> some View {
        HStack(spacing: TempoTheme.Space.sm) {
            TempoKeyCap(text: key)
            Text(label)
                .font(.system(size: TempoTheme.FontSize.micro))
                .foregroundStyle(TempoTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label)，快捷键 \(key)")
    }

    private func dateButton(
        selection: TaskPanelViewModel.DateSelection,
        day: LocalDay,
        title: String
    ) -> some View {
        let isSelected = viewModel.selection == selection
        return Button {
            viewModel.select(selection)
        } label: {
            DateButtonLabel(day: day, title: title, isSelected: isSelected)
        }
        .buttonStyle(TempoPressableButtonStyle())
        .accessibilityLabel("\(title)，\(day.displayDate)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .padding(.horizontal, TempoTheme.Space.sm)
        .padding(.bottom, TempoTheme.Space.sm)
    }

    private var customDateButton: some View {
        let day = viewModel.lastCustomDay
        let isSelected: Bool = {
            guard case .custom = viewModel.selection else { return false }
            return true
        }()

        return Button {
            viewModel.isDatePickerPresented = true
        } label: {
            if let day {
                DateButtonLabel(day: day, title: day.displayDate, isSelected: isSelected)
            } else {
                EmptyDateButtonLabel()
            }
        }
        .buttonStyle(TempoPressableButtonStyle())
        .accessibilityLabel(day.map { "自定义日期，\($0.displayDate)" } ?? "选择日期")
        .padding(.horizontal, TempoTheme.Space.sm)
        .popover(isPresented: $viewModel.isDatePickerPresented, arrowEdge: .leading) {
            DatePicker(
                "选择任务日期",
                selection: Binding(
                    get: { viewModel.lastCustomDay?.date() ?? Date() },
                    set: viewModel.chooseCustomDate
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(TempoTheme.Space.md)
            .frame(width: 280)
        }
    }
}

// MARK: - 日期项

private struct DateButtonLabel: View {
    let day: LocalDay
    let title: String
    let isSelected: Bool

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: TempoTheme.Space.sm) {
            Text(day.day, format: .number)
                .font(.system(size: TempoTheme.FontSize.dayNumber, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .frame(width: TempoTheme.Space.xxl)

            VStack(alignment: .leading, spacing: TempoTheme.Space.xs) {
                Text(title)
                    .font(.system(size: TempoTheme.FontSize.label, weight: .semibold))
                    .lineLimit(1)
                Text(day.displayWeekday)
                    .font(.system(size: TempoTheme.FontSize.micro))
                    .foregroundStyle(
                        isSelected ? TempoTheme.focusBlue.opacity(0.78) : TempoTheme.secondaryText
                    )
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected || isHovering ? TempoTheme.primaryText : TempoTheme.secondaryText)
        .padding(.horizontal, TempoTheme.Space.sm)
        .frame(height: 56)
        .background {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous)
                .fill(backgroundFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(
            reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick),
            value: isHovering
        )
    }

    private var backgroundFill: Color {
        if isSelected { return TempoTheme.focusBlue.opacity(0.13) }
        if isHovering { return Color.white.opacity(0.04) }
        return .clear
    }

    private var borderColor: Color {
        if isSelected { return TempoTheme.focusBlue.opacity(0.32) }
        if isHovering { return TempoTheme.hairline }
        return .clear
    }
}

private struct EmptyDateButtonLabel: View {
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: TempoTheme.Space.sm) {
            Image(systemName: "calendar")
                .frame(width: TempoTheme.Space.xxl)
            Text("选择日期")
            Spacer(minLength: 0)
        }
        .font(.system(size: TempoTheme.FontSize.label, weight: .medium))
        .foregroundStyle(isHovering ? TempoTheme.primaryText : TempoTheme.secondaryText)
        .padding(.horizontal, TempoTheme.Space.sm)
        .frame(height: 56)
        .background {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous)
                .fill(isHovering ? Color.white.opacity(0.04) : .clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(
            reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick),
            value: isHovering
        )
    }
}

// MARK: - 快速添加

private struct QuickAddView: View {
    @Bindable var viewModel: TaskPanelViewModel
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: TempoTheme.Space.sm) {
            HStack(spacing: TempoTheme.Space.md) {
                leadingGlyph

                TextField(placeholder, text: $viewModel.draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: TempoTheme.FontSize.body, weight: .medium))
                    .foregroundStyle(TempoTheme.primaryText)
                    .focused($isFocused)
                    .onSubmit(viewModel.submitDraft)
                    .onChange(of: viewModel.draft) { _, _ in viewModel.draftDidChange() }
                    .accessibilityLabel("添加任务")

                submitButton
            }
            .padding(.horizontal, TempoTheme.Space.lg)
            .frame(height: 62)
            .background(TempoTheme.raised.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.control, style: .continuous))
            // DESIGN.md 第 4 节：聚焦时 1 pt 蓝边 + 3 pt 低透明蓝环，不用外发光。
            .overlay {
                RoundedRectangle(cornerRadius: TempoTheme.Radius.control, style: .continuous)
                    .stroke(isFocused ? TempoTheme.focusBlue : TempoTheme.strongBorder, lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: TempoTheme.Radius.control + 3, style: .continuous)
                    .stroke(TempoTheme.focusBlue.opacity(isFocused ? 0.22 : 0), lineWidth: 3)
                    .padding(-3)
            }
            .shadow(color: .black.opacity(0.24), radius: 14, y: 8)
            .animation(
                reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick),
                value: isFocused
            )

            if let error = viewModel.inputError {
                Text(error)
                    .font(.system(size: TempoTheme.FontSize.caption))
                    .foregroundStyle(TempoTheme.completionCoral)
                    .accessibilityLabel("输入错误：\(error)")
            }
        }
        .padding(.horizontal, TempoTheme.Space.xl)
        .padding(.bottom, TempoTheme.Space.lg)
        .onReceive(NotificationCenter.default.publisher(for: .tempoFocusInput)) { _ in
            isFocused = true
        }
    }

    /// 语气化的提问放在这里，随所选日期变化，比固定标题更有用。
    private var placeholder: String {
        switch viewModel.selection {
        case .today: "今天要完成什么？回车保存"
        case .tomorrow: "明天准备做什么？回车保存"
        case .custom: "这一天要完成什么？回车保存"
        }
    }

    /// 加号是中性动作，不占用珊瑚红；聚焦时才升到焦点蓝。
    private var leadingGlyph: some View {
        RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous)
            .fill(isFocused ? TempoTheme.focusBlue.opacity(0.16) : TempoTheme.raisedHover)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "plus")
                    .font(.system(size: TempoTheme.FontSize.label, weight: .semibold))
                    .foregroundStyle(isFocused ? TempoTheme.focusBlue : TempoTheme.secondaryText)
            }
    }

    private var submitButton: some View {
        let isEnabled = !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return Button(action: viewModel.submitDraft) {
            HStack(spacing: TempoTheme.Space.xs + 2) {
                Text("添加")
                Text("↵")
                    .font(.system(size: TempoTheme.FontSize.micro, weight: .semibold, design: .monospaced))
            }
            .font(.system(size: TempoTheme.FontSize.caption, weight: .semibold))
            .foregroundStyle(isEnabled ? .white : TempoTheme.completedText)
            .padding(.horizontal, TempoTheme.Space.md)
            .frame(height: 30)
            .background(isEnabled ? TempoTheme.focusBlue.opacity(0.72) : TempoTheme.raisedHover)
            .clipShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous))
        }
        .buttonStyle(TempoPressableButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel("添加任务")
        .animation(
            reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick),
            value: isEnabled
        )
    }
}

// MARK: - 任务列表

private struct TaskListView: View {
    @Bindable var viewModel: TaskPanelViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: TempoTheme.Space.md) {
                TempoSectionLabel(text: "任务队列")
                Rectangle().fill(TempoTheme.hairline).frame(height: 1)
            }
            .padding(.horizontal, TempoTheme.Space.xl)
            .padding(.bottom, TempoTheme.Space.sm)

            Group {
                if !viewModel.tasks.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.tasks, id: \.id) { task in
                                TaskRowView(
                                    task: task,
                                    onToggle: { viewModel.toggleCompletion(task) },
                                    onDelete: { viewModel.delete(task) }
                                )
                            }
                        }
                        .padding(.horizontal, TempoTheme.Space.md)
                    }
                    .scrollIndicators(.hidden)
                } else if viewModel.loadError == nil {
                    emptyState
                } else {
                    Spacer(minLength: 0)
                }
            }

            if let error = viewModel.loadError {
                errorBanner(error)
            }

            if viewModel.undoSnapshot != nil {
                undoBanner
                    .transition(.opacity)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.standard),
                        value: viewModel.undoSnapshot != nil
                    )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: TempoTheme.Space.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(TempoTheme.completedText)
            Text(viewModel.emptyStateMessage)
                .font(.system(size: TempoTheme.FontSize.body, weight: .medium))
                .foregroundStyle(TempoTheme.primaryText)
            Text("在上方输入，按回车保存")
                .font(.system(size: TempoTheme.FontSize.caption))
                .foregroundStyle(TempoTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: TempoTheme.Space.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: TempoTheme.FontSize.caption))
                .foregroundStyle(TempoTheme.completionCoral)
            Text(message)
                .font(.system(size: TempoTheme.FontSize.caption))
                .foregroundStyle(TempoTheme.primaryText)
            Spacer()
            Button(viewModel.undoRetryRequired ? "重试撤销" : "重试", action: viewModel.retryLoad)
                .buttonStyle(TempoPressableButtonStyle())
                .font(.system(size: TempoTheme.FontSize.caption, weight: .semibold))
                .foregroundStyle(TempoTheme.focusBlue)
        }
        .padding(.horizontal, TempoTheme.Space.lg)
        .frame(height: 38)
        .background(TempoTheme.completionCoral.opacity(0.09))
        .overlay(alignment: .top) {
            Rectangle().fill(TempoTheme.completionCoral.opacity(0.22)).frame(height: 1)
        }
    }

    /// DESIGN.md 第 4 节：撤销提示是 10 pt 圆角的 raised 浮层，不是通栏条。
    private var undoBanner: some View {
        HStack(spacing: TempoTheme.Space.md) {
            Image(systemName: "trash")
                .font(.system(size: TempoTheme.FontSize.caption))
                .foregroundStyle(TempoTheme.secondaryText)
            Text("已删除任务")
                .font(.system(size: TempoTheme.FontSize.caption, weight: .medium))
                .foregroundStyle(TempoTheme.primaryText)
            Spacer()
            Button(viewModel.undoRetryRequired ? "重试撤销" : "撤销", action: viewModel.undoDelete)
                .buttonStyle(TempoPressableButtonStyle())
                .font(.system(size: TempoTheme.FontSize.caption, weight: .semibold))
                .foregroundStyle(TempoTheme.focusBlue)
        }
        .padding(.horizontal, TempoTheme.Space.lg)
        .frame(height: 40)
        .background(TempoTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous)
                .stroke(TempoTheme.strongBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 12, y: 6)
        .padding(.horizontal, TempoTheme.Space.xl)
        .padding(.bottom, TempoTheme.Space.lg)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 任务行

private struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: TempoTheme.Space.md) {
            checkbox

            // 原本的副标题「任务」每行都一样，右侧日期 chip 与左栏所选日期重复，两处都去掉。
            Text(task.title)
                .font(.system(size: TempoTheme.FontSize.body, weight: .medium))
                .foregroundStyle(task.isCompleted ? TempoTheme.completedText : TempoTheme.primaryText)
                .strikethrough(task.isCompleted, color: TempoTheme.completedText)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            deleteButton
        }
        .padding(.horizontal, TempoTheme.Space.md)
        .padding(.vertical, TempoTheme.Space.md)
        .background {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.control, style: .continuous)
                .fill(isHovering ? Color.white.opacity(0.03) : .clear)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(TempoTheme.hairline)
                .frame(height: 1)
                .padding(.horizontal, TempoTheme.Space.md)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(
            reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick),
            value: isHovering
        )
    }

    private var checkbox: some View {
        Button(action: onToggle) {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous)
                .fill(task.isCompleted ? TempoTheme.completionCoral : TempoTheme.canvas)
                .frame(width: 18, height: 18)
                .overlay {
                    RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous)
                        .stroke(checkboxBorder, lineWidth: 1)
                }
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: TempoTheme.FontSize.micro, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(task.isCompleted ? 1 : 0)
                }
        }
        .buttonStyle(TempoPressableButtonStyle())
        .accessibilityLabel(task.isCompleted ? "标记为未完成" : "标记为已完成")
        // DESIGN.md 第 9 节：只做颜色与透明度反馈，不位移。
        .animation(
            reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick),
            value: task.isCompleted
        )
    }

    private var checkboxBorder: Color {
        if task.isCompleted { return TempoTheme.completionCoral }
        return isHovering ? Color.white.opacity(0.38) : Color.white.opacity(0.23)
    }

    /// DESIGN.md 第 4 节：删除按钮悬停任务行时才显现。
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: TempoTheme.FontSize.caption, weight: .medium))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(TempoPressableButtonStyle())
        .foregroundStyle(TempoTheme.completionCoral)
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
        .accessibilityLabel("删除任务：\(task.title)")
        .accessibilityHidden(false)
    }
}
