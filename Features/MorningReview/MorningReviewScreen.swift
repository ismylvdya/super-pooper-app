import SwiftUI

/// Morning review: the pool as a table — one row per task with property chips edited in place,
/// rows reorder by dragging. Until the first drag the order follows the automatic sort after every
/// edit; after it the manual order is kept for today. "Reset to auto" brings the sort back.
struct MorningReviewScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tokens) private var tokens

    var body: some View {
        NavigationStack {
            let plan = model.plan(at: model.clock.now)
            List {
                Section {
                    ForEach(plan.pool) { item in
                        ReviewRow(item: item, today: plan.today)
                            .listRowBackground(tokens.color(.plateBackground))
                            .accessibilityIdentifier("review:\(item.id)")
                    }
                    .onMove { source, destination in
                        var names = plan.pool.map(\.id)
                        names.move(fromOffsets: source, toOffset: destination)
                        Haptics.play(.medium)
                        model.setManualOrder(names)
                    }
                } footer: {
                    Text(model.dayState.manualOrder == nil ? "review.footer.auto" : "review.footer.manual")
                        .accessibilityIdentifier("review.footer")
                }
            }
            .environment(\.editMode, .constant(.active))
            .bannerHost()
            .navigationTitle(Text("review.title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { route in
                if case .task(let name) = route { TaskPageScreen(taskName: name) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("review.reset") {
                        model.resetOrder()
                        model.banners.show(L10n.string("banner.orderReset"))
                    }
                    .disabled(model.dayState.manualOrder == nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

/// One table row: title (opens the page) and editable chips: High, date, estimate, energy,
/// pleasant, status, links.
struct ReviewRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.rules) private var rules
    let item: DayItem
    let today: LocalDate

    private var task: TaskNote { item.task }

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            NavigationLink(value: Route.task(task.name)) {
                HStack(spacing: tokens.space(.chipGap)) {
                    if item.isHabit { Image(systemName: icons[.habit]).foregroundStyle(tokens.color(.habit)) }
                    Text(task.name).foregroundStyle(item.isDone ? tokens.color(.secondaryText) : tokens.color(.primaryText))
                    if item.isBlocked { Image(systemName: icons[.blocked]).foregroundStyle(tokens.color(.secondaryText)) }
                }
            }
            ChipFlow(spacing: tokens.space(.chipGap)) {
                toggleChip(.high, isOn: task.isHighPriority, tint: tokens.color(.high)) { [.highPriority(!task.isHighPriority)] }
                dueChip
                estimateChip
                toggleChip(.energy, isOn: task.needEnergy, tint: tokens.color(.energy)) { [.needEnergy(!task.needEnergy)] }
                toggleChip(task.pleasant == false ? .unpleasant : .pleasant, isOn: task.pleasant != nil,
                           tint: task.pleasant == false ? tokens.color(.unpleasant) : tokens.color(.pleasant)) {
                    [.pleasant(task.pleasant == false ? true : false)]
                }
                if !task.isRecurring { statusChip }
                if !task.previousTasks.isEmpty || item.isBlocked {
                    Chip(icon: .previousTasks, text: "\(task.previousTasks.count)")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func toggleChip(_ icon: Icon, isOn: Bool, tint: Color, changes: @escaping () -> [TaskFieldChange]) -> some View {
        Button {
            Haptics.play(.light)
            Task { await model.update(task.name, changes()) }
        } label: {
            Chip(icon: icon, tint: tint, isOn: isOn)
        }
        .buttonStyle(.borderless)
    }

    private var dueChip: some View {
        Menu {
            let options: [(LocalizedStringKey, LocalDate?)] = [
                ("due.today", today), ("due.tomorrow", today.adding(days: 1)),
                ("review.due.weekEnd", model.context().weekEnd), ("review.due.clear", nil),
            ]
            ForEach(options.indices, id: \.self) { index in
                Button(options[index].0) {
                    let day = options[index].1
                    Task { await model.update(task.name, [.due(day.map { TaskDue(day: $0, time: task.due?.time) })]) }
                }
            }
        } label: {
            Chip(icon: .due, text: task.due.map { DueText.format($0, today: today) }, isOn: task.due != nil)
        }
    }

    private var estimateChip: some View {
        Menu {
            ForEach(rules.timeEstimates, id: \.minutes) { option in
                Button(LocalizedStringKey(option.label)) { Task { await model.update(task.name, [.timeEstimate(option.minutes)]) } }
            }
        } label: {
            Chip(icon: .estimate, text: EstimateText.label(task.timeEstimate, rules: rules))
        }
    }

    private var statusChip: some View {
        Menu {
            ForEach(TaskStatus.known.filter { $0 != .done }, id: \.self) { status in
                Button(StatusText.title(status)) {
                    let changes = TaskMarking(today: today).changes(setting: status, on: task)
                    Task { await model.update(task.name, changes) }
                }
            }
        } label: {
            Chip(icon: .status, text: StatusText.title(task.status))
        }
    }
}
