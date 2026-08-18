import SwiftUI

struct TaskPanelView: View {
    @Bindable var viewModel: TaskPanelViewModel
    let onClose: () -> Void

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
                DateRailView(viewModel: viewModel)
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(TempoTheme.strongBorder, lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
        .onExitCommand(perform: onClose)
    }

    private var panelHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.selectedDay.weekday())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(TempoTheme.completionCoral)

                Text(headerTitle)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(TempoTheme.primaryText)
            }

            Spacer()

            HStack(spacing: 18) {
                metric(value: viewModel.tasks.count, label: "任务")
                metric(value: viewModel.completedCount, label: "完成")
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    private var headerTitle: String {
        switch viewModel.selection {
        case .today: "今天要完成什么？"
        case .tomorrow: "明天准备做什么？"
        case .custom: "这一天要完成什么？"
        }
    }

    private func metric(value: Int, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value, format: .number.precision(.integerLength(2)))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(TempoTheme.primaryText)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(TempoTheme.secondaryText)
        }
    }
}

private struct DateRailView: View {
    @Bindable var viewModel: TaskPanelViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(TempoTheme.completionCoral)
                    .frame(width: 23, height: 23)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                Text("Tempo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TempoTheme.primaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 19)
            .padding(.bottom, 24)

            Text("日程")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(TempoTheme.secondaryText)
                .padding(.horizontal, 17)
                .padding(.bottom, 10)

            dateButton(
                selection: .today,
                day: viewModel.today,
                title: "今天"
            )
            dateButton(
                selection: .tomorrow,
                day: viewModel.tomorrow,
                title: "明天"
            )

            customDateButton

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("完成进度")
                    Spacer()
                    Text("\(viewModel.completedCount) / \(viewModel.tasks.count)")
                        .monospacedDigit()
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(TempoTheme.secondaryText)

                GeometryReader { proxy in
                    let total = max(viewModel.tasks.count, 1)
                    let progress = CGFloat(viewModel.completedCount) / CGFloat(total)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(TempoTheme.completionCoral)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 3)
            }
            .padding(16)
        }
        .background(TempoTheme.surface.opacity(0.78))
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
            dateButtonLabel(day: day, title: title, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(day.formatted())")
        .padding(.horizontal, 10)
        .padding(.bottom, 7)
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
                dateButtonLabel(day: day, title: day.formatted(), isSelected: isSelected)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .frame(width: 36)
                    Text("选择日期")
                    Spacer()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TempoTheme.secondaryText)
                .padding(.horizontal, 10)
                .frame(height: 56)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
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
            .padding(12)
            .frame(width: 280)
        }
    }

    private func dateButtonLabel(day: LocalDay, title: String, isSelected: Bool) -> some View {
        HStack(spacing: 9) {
            Text(day.day, format: .number)
                .font(.system(size: 19, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(day.weekday())
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? TempoTheme.focusBlue.opacity(0.78) : TempoTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? TempoTheme.primaryText : TempoTheme.secondaryText)
        .padding(.horizontal, 10)
        .frame(height: 56)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? TempoTheme.focusBlue.opacity(0.13) : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? TempoTheme.focusBlue.opacity(0.32) : Color.clear, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct QuickAddView: View {
    @Bindable var viewModel: TaskPanelViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 11) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(TempoTheme.completionCoral.opacity(0.14))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TempoTheme.completionCoral)
                    }

                TextField("输入任务，按回车快速添加…", text: $viewModel.draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TempoTheme.primaryText)
                    .focused($isFocused)
                    .onSubmit(viewModel.submitDraft)
                    .onChange(of: viewModel.draft) { _, _ in viewModel.draftDidChange() }
                    .accessibilityLabel("添加任务")

                Text(viewModel.selectedDateLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TempoTheme.secondaryText)
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .background(TempoTheme.raised)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(TempoTheme.hairline, lineWidth: 1)
                    }

                Button(action: viewModel.submitDraft) {
                    HStack(spacing: 6) {
                        Text("添加")
                        Text("↵")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(TempoTheme.focusBlue.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加任务")
            }
            .padding(.horizontal, 14)
            .frame(height: 62)
            .background(TempoTheme.raised.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? TempoTheme.focusBlue.opacity(0.72) : TempoTheme.strongBorder, lineWidth: 1)
            }
            .shadow(color: isFocused ? TempoTheme.focusBlue.opacity(0.10) : .black.opacity(0.24), radius: isFocused ? 8 : 14, y: 8)

            if let error = viewModel.inputError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(TempoTheme.completionCoral)
                    .accessibilityLabel("输入错误：\(error)")
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 17)
        .onReceive(NotificationCenter.default.publisher(for: .tempoFocusInput)) { _ in
            isFocused = true
        }
    }
}

private struct TaskListView: View {
    @Bindable var viewModel: TaskPanelViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("任务队列")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.25)
                    .foregroundStyle(TempoTheme.secondaryText)
                Rectangle().fill(TempoTheme.hairline).frame(height: 1)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 8)

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
                        .padding(.horizontal, 26)
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
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: viewModel.undoSnapshot != nil)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(TempoTheme.secondaryText)
            Text(viewModel.emptyStateMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TempoTheme.primaryText)
            Text("在上方输入，按回车保存")
                .font(.system(size: 11))
                .foregroundStyle(TempoTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(TempoTheme.completionCoral)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(TempoTheme.primaryText)
            Spacer()
            Button(viewModel.undoRetryRequired ? "重试撤销" : "重试", action: viewModel.retryLoad)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TempoTheme.focusBlue)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(TempoTheme.completionCoral.opacity(0.09))
        .overlay(alignment: .top) { Rectangle().fill(TempoTheme.completionCoral.opacity(0.22)).frame(height: 1) }
    }

    private var undoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash")
                .foregroundStyle(TempoTheme.secondaryText)
            Text("已删除任务")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TempoTheme.primaryText)
            Spacer()
            Button(viewModel.undoRetryRequired ? "重试撤销" : "撤销", action: viewModel.undoDelete)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TempoTheme.focusBlue)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(TempoTheme.raised)
        .overlay(alignment: .top) { Rectangle().fill(TempoTheme.strongBorder).frame(height: 1) }
        .accessibilityElement(children: .contain)
    }
}

private struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(task.isCompleted ? TempoTheme.completionCoral : TempoTheme.canvas)
                    .frame(width: 19, height: 19)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(task.isCompleted ? TempoTheme.completionCoral : Color.white.opacity(0.23), lineWidth: 1)
                    }
                    .overlay {
                        if task.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "标记为未完成" : "标记为已完成")

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(task.isCompleted ? TempoTheme.completedText : TempoTheme.primaryText)
                    .strikethrough(task.isCompleted, color: TempoTheme.completedText)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(task.isCompleted ? "已完成" : "任务")
                    .font(.system(size: 10))
                    .foregroundStyle(task.isCompleted ? TempoTheme.completedText : TempoTheme.secondaryText)
            }

            Text(task.localDay.formatted())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(TempoTheme.secondaryText)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(TempoTheme.raised.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isHovering ? TempoTheme.completionCoral : TempoTheme.secondaryText.opacity(0.35))
            .accessibilityLabel("删除任务：\(task.title)")
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle().fill(TempoTheme.hairline).frame(height: 1)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}
