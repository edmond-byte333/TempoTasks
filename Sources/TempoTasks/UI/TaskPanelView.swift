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
        HStack(spacing: 0) {
            DateRailView(
                viewModel: viewModel,
                onDragBegan: onDragBegan,
                onDragEnded: onDragEnded
            )
            .frame(width: 168)

            // 左右分栏靠背景明度差，不靠 1 pt 分隔线。
            VStack(spacing: 0) {
                panelHeader
                // 已完成是只读归档，输入框在那里没有意义。
                if viewModel.acceptsNewTasks {
                    QuickAddView(viewModel: viewModel)
                }
                TaskListView(viewModel: viewModel)
            }
            .background(TempoTheme.canvas)
        }
        .frame(width: 760, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.panel, style: .continuous)
                .stroke(TempoTheme.border, lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
        .onExitCommand(perform: onClose)
    }

    // MARK: - 头部

    private var panelHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: TempoTheme.Space.xs + 2) {
                Text(viewModel.selectedDateLabel)
                    .font(.system(size: TempoTheme.FontSize.display, weight: .semibold))
                    .foregroundStyle(TempoTheme.textPrimary)

                if !headerSubtitle.isEmpty {
                    Text(headerSubtitle)
                        .font(.system(size: TempoTheme.FontSize.caption))
                        .foregroundStyle(TempoTheme.textSecondary)
                }
            }

            Spacer(minLength: TempoTheme.Space.lg)

            // 完成度只对具体某一天有意义。待办里的东西还没被安排，
            // 归档里的又全是完成的，两处都不该出现进度。
            if !viewModel.isViewingBacklog, !viewModel.isViewingCompleted {
                dayProgress
            }
        }
        .padding(.horizontal, TempoTheme.Space.xl)
        .padding(.top, TempoTheme.Space.xl)
        .padding(.bottom, TempoTheme.Space.lg)
        .overlay {
            WindowDragSurface(onDragBegan: onDragBegan, onDragEnded: onDragEnded)
        }
    }

    private var headerSubtitle: String {
        if viewModel.isViewingBacklog {
            return viewModel.backlogSummary
        }
        if viewModel.isViewingCompleted {
            return viewModel.tasks.isEmpty ? "" : "最近 \(viewModel.tasks.count) 条"
        }
        return "\(viewModel.selectedDay.displayDate) · \(viewModel.selectedDay.displayWeekday)"
    }

    /// 只有具体某天才有「完成度」可言；待办里的东西还没被安排，进度条没有意义。
    private var dayProgress: some View {
        let total = viewModel.tasks.count
        let done = viewModel.completedCount

        return HStack(alignment: .firstTextBaseline, spacing: TempoTheme.Space.xs + 2) {
            Text(done, format: .number)
                .font(.system(size: TempoTheme.FontSize.title, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(done > 0 ? TempoTheme.textPrimary : TempoTheme.textSecondary)
                .contentTransition(.numericText())

            Text("/ \(total) 完成")
                .font(.system(size: TempoTheme.FontSize.caption))
                .foregroundStyle(TempoTheme.textSecondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("共 \(total) 个任务，已完成 \(done) 个")
    }
}

// MARK: - 左侧轨道

private struct DateRailView: View {
    @Bindable var viewModel: TaskPanelViewModel
    let onDragBegan: () -> Void
    let onDragEnded: (NSRect, NSRect) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandMark

            backlogButton
                .padding(.bottom, TempoTheme.Space.lg)

            TempoSectionLabel(text: "日程")
                .padding(.horizontal, TempoTheme.Space.lg)
                .padding(.bottom, TempoTheme.Space.sm)

            dateButton(selection: .today, day: viewModel.today, title: "今天")
            dateButton(selection: .tomorrow, day: viewModel.tomorrow, title: "明天")
            customDateButton

            Spacer(minLength: TempoTheme.Space.lg)

            completedButton
                .padding(.bottom, TempoTheme.Space.lg)

            shortcutHints
        }
        .background(TempoTheme.surface)
    }

    private var brandMark: some View {
        HStack(spacing: TempoTheme.Space.sm) {
            Image(systemName: "checkmark.square")
                .font(.system(size: TempoTheme.FontSize.body, weight: .medium))
                .foregroundStyle(TempoTheme.textSecondary)

            Text("Tempo")
                .font(.system(size: TempoTheme.FontSize.body, weight: .semibold))
                .foregroundStyle(TempoTheme.textPrimary)
        }
        .padding(.horizontal, TempoTheme.Space.lg)
        .padding(.top, TempoTheme.Space.xl)
        .padding(.bottom, TempoTheme.Space.xl)
        .overlay {
            WindowDragSurface(onDragBegan: onDragBegan, onDragEnded: onDragEnded)
        }
    }

    /// 默认落点：唤出即可打字，不必先决定日期。
    private var backlogButton: some View {
        let isSelected = viewModel.selection == .backlog
        return Button {
            viewModel.select(.backlog)
        } label: {
            BacklogButtonLabel(count: viewModel.backlogCount, isSelected: isSelected)
        }
        .buttonStyle(TempoPressableButtonStyle())
        .accessibilityLabel("待办，\(viewModel.backlogCount) 件")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .padding(.horizontal, TempoTheme.Space.sm)
    }

    /// 归档入口。放在日程下面、靠近底部，它是偶尔回看的东西，不该和主流程抢位置。
    private var completedButton: some View {
        let isSelected = viewModel.selection == .completed
        return Button {
            viewModel.select(.completed)
        } label: {
            HStack(spacing: TempoTheme.Space.sm) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: TempoTheme.FontSize.label))
                    .frame(width: 20)
                Text("已完成")
                    .font(.system(size: TempoTheme.FontSize.label, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? TempoTheme.textPrimary : TempoTheme.textDim)
            .padding(.horizontal, TempoTheme.Space.md)
            .frame(height: 36)
            .background {
                RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous)
                    .fill(isSelected ? TempoTheme.accentSurface : .clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous))
        }
        .buttonStyle(TempoPressableButtonStyle())
        .accessibilityLabel("已完成的任务记录")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .padding(.horizontal, TempoTheme.Space.sm)
    }

    private var shortcutHints: some View {
        VStack(alignment: .leading, spacing: TempoTheme.Space.sm) {
            HStack(spacing: TempoTheme.Space.sm) {
                TempoSectionLabel(text: "快捷键")
                Spacer(minLength: 0)
                if viewModel.hotKeyCombo != .default {
                    Button {
                        viewModel.updateHotKey(.default)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: TempoTheme.FontSize.micro, weight: .semibold))
                            .foregroundStyle(TempoTheme.textSecondary)
                            .frame(width: TempoTheme.Space.lg, height: TempoTheme.Space.lg)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(TempoPressableButtonStyle())
                    .help("恢复默认快捷键 \(HotKeyCombo.default.displayString)")
                    .accessibilityLabel("恢复默认快捷键")
                }
            }

            HotKeyRecorderView(
                combo: viewModel.hotKeyCombo,
                isConflicting: !viewModel.hotKeyAvailable,
                onChange: viewModel.updateHotKey
            )

            HStack(spacing: TempoTheme.Space.sm) {
                TempoKeyCap(text: "esc")
                Text("关闭面板")
                    .font(.system(size: TempoTheme.FontSize.micro))
                    .foregroundStyle(TempoTheme.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("关闭面板，快捷键 esc")
        }
        .padding(.horizontal, TempoTheme.Space.lg)
        .padding(.bottom, TempoTheme.Space.lg)
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
        .padding(.bottom, TempoTheme.Space.xs)
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

// MARK: - 左栏条目

private struct BacklogButtonLabel: View {
    let count: Int
    let isSelected: Bool

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: TempoTheme.Space.sm) {
            Image(systemName: "tray.full")
                .font(.system(size: TempoTheme.FontSize.label))
                .frame(width: 20)

            Text("待办")
                .font(.system(size: TempoTheme.FontSize.title, weight: .semibold))

            Spacer(minLength: 0)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: TempoTheme.FontSize.micro, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? TempoTheme.canvas : TempoTheme.textPrimary)
                    .padding(.horizontal, TempoTheme.Space.xs + 1)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(isSelected ? TempoTheme.accent : TempoTheme.raised)
                    .clipShape(Capsule())
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, TempoTheme.Space.md)
        .frame(height: 44)
        .background {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous)
                .fill(background)
        }
        .contentShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick), value: isHovering)
    }

    private var foreground: Color {
        if isSelected { return TempoTheme.textUrgent }
        return isHovering ? TempoTheme.textPrimary : TempoTheme.textSecondary
    }

    private var background: Color {
        if isSelected { return TempoTheme.accentSurface }
        return isHovering ? TempoTheme.rowHover : .clear
    }
}

private struct DateButtonLabel: View {
    let day: LocalDay
    let title: String
    let isSelected: Bool

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: TempoTheme.Space.sm) {
            Text(day.day, format: .number)
                .font(.system(size: TempoTheme.FontSize.dayNumber, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .frame(width: 20, alignment: .center)
                .foregroundStyle(isSelected ? TempoTheme.accent : TempoTheme.textSecondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: TempoTheme.FontSize.label, weight: .medium))
                    .lineLimit(1)
                Text(day.displayWeekday)
                    .font(.system(size: TempoTheme.FontSize.micro))
                    .foregroundStyle(TempoTheme.textDim)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? TempoTheme.textPrimary : TempoTheme.textSecondary)
        .padding(.horizontal, TempoTheme.Space.md)
        .frame(height: 44)
        .background {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous)
                .fill(isSelected ? TempoTheme.accentSurface : (isHovering ? TempoTheme.rowHover : .clear))
        }
        .contentShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick), value: isHovering)
    }
}

private struct EmptyDateButtonLabel: View {
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: TempoTheme.Space.sm) {
            Image(systemName: "calendar")
                .font(.system(size: TempoTheme.FontSize.label))
                .frame(width: 20)
            Text("选择日期")
                .font(.system(size: TempoTheme.FontSize.label, weight: .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(isHovering ? TempoTheme.textPrimary : TempoTheme.textSecondary)
        .padding(.horizontal, TempoTheme.Space.md)
        .frame(height: 44)
        .background {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous)
                .fill(isHovering ? TempoTheme.rowHover : .clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous))
        .onHover { isHovering = $0 }
    }
}

// MARK: - 快速输入

private struct QuickAddView: View {
    @Bindable var viewModel: TaskPanelViewModel
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: TempoTheme.Space.sm) {
            HStack(spacing: TempoTheme.Space.md) {
                TextField(placeholder, text: $viewModel.draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: TempoTheme.FontSize.title))
                    .foregroundStyle(TempoTheme.textUrgent)
                    .focused($isFocused)
                    .onSubmit(viewModel.submitDraft)
                    .onChange(of: viewModel.draft) { _, _ in viewModel.draftDidChange() }
                    .accessibilityLabel("添加任务")

                if !viewModel.draft.isEmpty {
                    TempoKeyCap(text: "↩")
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, TempoTheme.Space.lg)
            .frame(height: 52)
            .background(isFocused ? TempoTheme.raised : TempoTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TempoTheme.Radius.control, style: .continuous)
                    .stroke(isFocused ? TempoTheme.accent : TempoTheme.hairline, lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: TempoTheme.Radius.control + 3, style: .continuous)
                    .stroke(TempoTheme.accentMuted.opacity(isFocused ? 1 : 0), lineWidth: 2)
                    .padding(-3)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick), value: isFocused)

            if let error = viewModel.inputError {
                Text(error)
                    .font(.system(size: TempoTheme.FontSize.caption))
                    .foregroundStyle(TempoTheme.alert)
                    .accessibilityLabel("输入错误：\(error)")
            }
        }
        .padding(.horizontal, TempoTheme.Space.xl)
        .padding(.bottom, TempoTheme.Space.xl)
        .onReceive(NotificationCenter.default.publisher(for: .tempoFocusInput)) { _ in
            isFocused = true
        }
    }

    private var placeholder: String {
        switch viewModel.selection {
        case .backlog: "记下来，之后再决定哪天做"
        case .today: "今天要完成什么？"
        case .tomorrow: "明天准备做什么？"
        case .custom: "这一天要完成什么？"
        // 已完成视图不显示输入框，这里只是让 switch 穷尽。
        case .completed: ""
        }
    }
}

// MARK: - 任务列表

private struct TaskListView: View {
    @Bindable var viewModel: TaskPanelViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if !viewModel.tasks.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if viewModel.isViewingBacklog {
                                backlogGroups
                            } else {
                                ForEach(viewModel.tasks, id: \.id) { task in
                                    row(for: task)
                                }
                            }
                        }
                        .padding(.horizontal, TempoTheme.Space.md)
                        .padding(.bottom, TempoTheme.Space.lg)
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

            if let batch = viewModel.bulkCompleted {
                bulkUndoBanner(count: batch.count)
                    .transition(.opacity)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.standard),
                        value: batch.count
                    )
            }
        }
    }

    /// 几十条的量级需要分组，否则逾期和未安排会糊成一片。
    @ViewBuilder
    private var backlogGroups: some View {
        let overdue = viewModel.tasks.filter { !$0.isUnscheduled }
        let unscheduled = viewModel.tasks.filter(\.isUnscheduled)

        // 新记下的落在「还没安排」，放最前面，回车后不用滚动就能看到。
        if !unscheduled.isEmpty {
            groupHeader("还没安排", count: unscheduled.count)
            ForEach(unscheduled, id: \.id) { row(for: $0) }
        }

        if !overdue.isEmpty {
            groupHeader("待处理", count: overdue.count) {
                viewModel.completeAll(overdue)
            }
            .padding(.top, unscheduled.isEmpty ? 0 : TempoTheme.Space.xl)
            ForEach(overdue, id: \.id) { row(for: $0) }
        }
    }

    /// 传入 onCompleteAll 时，标题行右侧出现整组完成的入口。
    private func groupHeader(
        _ title: String,
        count: Int,
        onCompleteAll: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: TempoTheme.Space.sm) {
            TempoSectionLabel(text: title)
            Text("\(count)")
                .font(.system(size: TempoTheme.FontSize.micro, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(TempoTheme.textDim)
            Spacer(minLength: 0)
            if let onCompleteAll {
                GroupCompleteButton(count: count, action: onCompleteAll)
            }
        }
        .padding(.horizontal, TempoTheme.Space.md)
        .padding(.bottom, TempoTheme.Space.sm)
    }

    private func row(for task: TaskItem) -> some View {
        TaskRowView(
            task: task,
            today: viewModel.today,
            isArchiveView: viewModel.isViewingCompleted,
            onToggle: { viewModel.toggleCompletion(task) },
            onDelete: { viewModel.delete(task) },
            onSchedule: { viewModel.schedule(task, to: $0) }
        )
    }

    /// 靠上放，紧跟输入框。垂直居中会让它漂在面板下半部，
    /// 离刚刚打完字的地方太远。
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: TempoTheme.Space.sm) {
            Text(viewModel.emptyStateMessage)
                .font(.system(size: TempoTheme.FontSize.title, weight: .medium))
                .foregroundStyle(TempoTheme.textSecondary)
            Text("在上方输入，回车保存")
                .font(.system(size: TempoTheme.FontSize.caption))
                .foregroundStyle(TempoTheme.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, TempoTheme.Space.xl)
        .accessibilityElement(children: .combine)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: TempoTheme.Space.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: TempoTheme.FontSize.caption))
                .foregroundStyle(TempoTheme.alert)
            Text(message)
                .font(.system(size: TempoTheme.FontSize.caption))
                .foregroundStyle(TempoTheme.textPrimary)
            Spacer()
            Button(viewModel.undoRetryRequired ? "重试撤销" : "重试", action: viewModel.retryLoad)
                .buttonStyle(TempoPressableButtonStyle())
                .font(.system(size: TempoTheme.FontSize.caption, weight: .semibold))
                .foregroundStyle(TempoTheme.accent)
        }
        .padding(.horizontal, TempoTheme.Space.lg)
        .frame(height: 40)
        .background(TempoTheme.alertSurface)
    }

    private func bulkUndoBanner(count: Int) -> some View {
        HStack(spacing: TempoTheme.Space.md) {
            Text("已完成 \(count) 件")
                .font(.system(size: TempoTheme.FontSize.caption))
                .foregroundStyle(TempoTheme.textSecondary)
                .monospacedDigit()
            Spacer()
            Button("撤销", action: viewModel.undoBulkComplete)
                .buttonStyle(TempoPressableButtonStyle())
                .font(.system(size: TempoTheme.FontSize.caption, weight: .semibold))
                .foregroundStyle(TempoTheme.accent)
        }
        .padding(.horizontal, TempoTheme.Space.lg)
        .frame(height: 40)
        .background(TempoTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous))
        .padding(.horizontal, TempoTheme.Space.xl)
        .padding(.bottom, TempoTheme.Space.lg)
        .accessibilityElement(children: .contain)
    }

    private var undoBanner: some View {
        HStack(spacing: TempoTheme.Space.md) {
            Text("已删除")
                .font(.system(size: TempoTheme.FontSize.caption))
                .foregroundStyle(TempoTheme.textSecondary)
            Spacer()
            Button(viewModel.undoRetryRequired ? "重试撤销" : "撤销", action: viewModel.undoDelete)
                .buttonStyle(TempoPressableButtonStyle())
                .font(.system(size: TempoTheme.FontSize.caption, weight: .semibold))
                .foregroundStyle(TempoTheme.accent)
        }
        .padding(.horizontal, TempoTheme.Space.lg)
        .frame(height: 40)
        .background(TempoTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: TempoTheme.Radius.row, style: .continuous))
        .padding(.horizontal, TempoTheme.Space.xl)
        .padding(.bottom, TempoTheme.Space.lg)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 任务行

/// 整组标记完成。默认低调，悬停才显出来，避免误点。
private struct GroupCompleteButton: View {
    let count: Int
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text("全部完成")
                .font(.system(size: TempoTheme.FontSize.micro, weight: .medium))
                .foregroundStyle(isHovering ? TempoTheme.textPrimary : TempoTheme.textDim)
                .padding(.horizontal, TempoTheme.Space.sm)
                .frame(height: 20)
                .background(isHovering ? TempoTheme.raised : .clear)
                .clipShape(Capsule())
                .contentShape(Rectangle())
        }
        .buttonStyle(TempoPressableButtonStyle())
        .onHover { isHovering = $0 }
        .help("把这 \(count) 件全部标记完成，5 秒内可撤销")
        .accessibilityLabel("全部完成，共 \(count) 件")
    }
}

private struct TaskRowView: View {
    let task: TaskItem
    let today: LocalDay
    /// 归档视图：显示完成日期，不提供改日期入口。
    let isArchiveView: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onSchedule: (LocalDay?) -> Void

    @State private var isHovering = false
    @State private var isPickingDate = false
    @State private var pickedDate = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var daysOverdue: Int {
        guard !task.isUnscheduled, !task.isCompleted else { return 0 }
        return max(0, task.localDay.daysBefore(today))
    }

    var body: some View {
        HStack(spacing: TempoTheme.Space.md) {
            checkbox

            Text(task.title)
                .font(.system(size: TempoTheme.FontSize.body, weight: titleWeight))
                .foregroundStyle(titleColor)
                .strikethrough(task.isCompleted, color: TempoTheme.textDim)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isArchiveView, let completedAt = task.completedAt {
                completionMark(completedAt)
            } else if daysOverdue > 0 {
                overdueMark
            }

            // 日期选择器打开时鼠标会移到 popover 上，行的 hover 随之失效。
            // 不带上 isPickingDate 的话，actions 会连同 popover 一起被销毁。
            if isHovering || isPickingDate {
                actions
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, TempoTheme.Space.md)
        .padding(.vertical, TempoTheme.Space.md)
        .background {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.control, style: .continuous)
                .fill(isHovering || isPickingDate ? TempoTheme.rowHover : .clear)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick), value: isHovering)
    }

    /// 亮度即优先级：欠得越久越亮。这是整套设计的主线。
    private var titleColor: Color {
        if task.isCompleted { return TempoTheme.textDim }
        if task.isUnscheduled { return TempoTheme.textSecondary }
        return TempoTheme.urgencyText(daysOverdue: daysOverdue)
    }

    private var titleWeight: Font.Weight {
        daysOverdue >= 7 ? .medium : .regular
    }

    /// 完成态不再用珊瑚红。完成的事应该退场，不该是画面里最重的颜色。
    private var checkbox: some View {
        Button(action: onToggle) {
            RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous)
                .fill(task.isCompleted ? TempoTheme.textDim : TempoTheme.canvas)
                .frame(width: 18, height: 18)
                .overlay {
                    RoundedRectangle(cornerRadius: TempoTheme.Radius.sm, style: .continuous)
                        .stroke(task.isCompleted ? TempoTheme.textDim : TempoTheme.border, lineWidth: 1)
                }
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: TempoTheme.FontSize.micro, weight: .bold))
                        .foregroundStyle(TempoTheme.canvas)
                        .opacity(task.isCompleted ? 1 : 0)
                }
        }
        .buttonStyle(TempoPressableButtonStyle())
        .accessibilityLabel(task.isCompleted ? "标记为未完成" : "标记为已完成")
        .animation(reduceMotion ? nil : .easeOut(duration: TempoTheme.Motion.quick), value: task.isCompleted)
    }

    /// 显示原定日期而不是相对天数：具体日期能带回当时的上下文。
    /// 紧迫感由标题亮度承担，这里不必重复表达。
    /// 纯数字，用等宽让多行之间竖向对齐。
    private var overdueMark: some View {
        Text(String(format: "%02d/%02d", task.localDay.month, task.localDay.day))
            .font(.system(size: TempoTheme.FontSize.micro, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(TempoTheme.urgencyAccent(daysOverdue: daysOverdue) ?? TempoTheme.textDim)
            .accessibilityLabel("原定 \(task.localDay.month) 月 \(task.localDay.day) 日，已逾期 \(daysOverdue) 天")
    }

    /// 归档里显示完成日期，回答的是「这是什么时候做完的」。
    private func completionMark(_ completedAt: Date) -> some View {
        let day = LocalDay(date: completedAt)
        return Text(String(format: "%02d/%02d", day.month, day.day))
            .font(.system(size: TempoTheme.FontSize.micro, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(TempoTheme.textDim)
            .accessibilityLabel("完成于 \(day.month) 月 \(day.day) 日")
    }

    private var actions: some View {
        HStack(spacing: TempoTheme.Space.xs) {
            // 归档里改日期没有意义，只保留删除。
            if !isArchiveView {
                scheduleMenu
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: TempoTheme.FontSize.caption, weight: .medium))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TempoPressableButtonStyle())
            .foregroundStyle(TempoTheme.textSecondary)
            .accessibilityLabel("删除任务：\(task.title)")
        }
    }

    private var scheduleMenu: some View {
        Menu {
            Button("今天") { onSchedule(today) }
            Button("明天") { onSchedule(today.addingDays(1)) }
            Button("选择日期…") {
                pickedDate = task.localDay.date() ?? Date()
                isPickingDate = true
            }
            if !task.isUnscheduled {
                Divider()
                Button("移回待办") { onSchedule(nil) }
            }
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: TempoTheme.FontSize.caption, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 26, height: 26)
        .foregroundStyle(TempoTheme.textSecondary)
        .help("改到别的日期")
        .accessibilityLabel("安排日期：\(task.title)")
        .popover(isPresented: $isPickingDate, arrowEdge: .bottom) {
            DatePicker(
                "安排到",
                selection: Binding(
                    get: { pickedDate },
                    set: { newValue in
                        pickedDate = newValue
                        onSchedule(LocalDay(date: newValue))
                        isPickingDate = false
                    }
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
