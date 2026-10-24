import SwiftUI

/// Morning review: the pool as a table — one row per task with property chips edited in place,
/// rows reorder by dragging. Until the first drag the order follows the automatic sort after every
/// edit; after it the manual order is kept for today. "Reset to auto" brings the sort back.
/// Tapping a row (outside its chips) opens the task page; "+" creates a new this-week task.
/// Swiping a row left takes it out of today: it stays this week and waits in "Postponed" at the bottom
/// (and in tomorrow's review); swiping it there brings it back.
struct MorningReviewScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            let plan = model.plan(at: model.clock.now)
            List {
                Section {
                    ForEach(plan.pool) { item in
                        ReviewRow(item: item, today: plan.today) { path.append(.task(item.id)) }
                            .listRowBackground(tokens.color(.plateBackground))
                            .accessibilityIdentifier("review:\(item.id)")
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button { model.postpone(item.id) } label: {
                                    Label("review.postpone", systemImage: icons[.postpone])
                                }
                                .tint(tokens.color(.swipeNeutral))
                            }
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
                if !model.postponedTasks.isEmpty {
                    Section {
                        ForEach(model.postponedTasks, id: \.name) { task in
                            ReviewRow(item: DayItem(task: task, state: .open, blockers: [], problems: []), today: plan.today) {
                                path.append(.task(task.name))
                            }
                            .listRowBackground(tokens.color(.plateBackground))
                            .opacity(tokens.opacity(.blocked))
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { model.unpostpone(task.name) } label: {
                                    Label("review.backToToday", systemImage: icons[.restore])
                                }
                                .tint(tokens.color(.success))
                            }
                        }
                    } header: {
                        Text("review.postponed")
                    } footer: {
                        Text("review.postponed.hint")
                    }
                }
            }
            .bannerHost()
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .task(let name): TaskPageScreen(taskName: name).bannerHost()
                case .newTask: NewNoteScreen(kind: .task).bannerHost()
                default: EmptyView()
                }
            }
            .navigationTitle(Text("review.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("review.reset") {
                        model.resetOrder()
                        model.banners.show(L10n.string("banner.orderReset"))
                    }
                    .disabled(model.dayState.manualOrder == nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { path.append(.newTask) } label: {
                        Image(systemName: icons[.newTask])
                    }
                    .accessibilityLabel(Text("task.new.add"))
                    .accessibilityIdentifier("task.new")
                }
            }
        }
    }
}

/// One table row: title and editable chips: High, date, estimate, energy,
/// pleasant, status, links.
struct ReviewRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.rules) private var rules
    let item: DayItem
    let today: LocalDate
    let onOpen: () -> Void
    @State private var isPickingDate = false

    private var task: TaskNote { item.task }

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            HStack(spacing: tokens.space(.chipGap)) {
                if item.isHabit { Image(systemName: icons[.habit]).foregroundStyle(tokens.color(.habit)) }
                Text(task.name).foregroundStyle(item.isDone ? tokens.color(.secondaryText) : tokens.color(.primaryText))
                if item.isBlocked { Image(systemName: icons[.blocked]).foregroundStyle(tokens.color(.secondaryText)) }
            }
            ChipFlow(spacing: tokens.space(.chipGap)) {
                toggleChip(.high, isOn: task.isHighPriority, tint: tokens.color(.high)) { [.highPriority(!task.isHighPriority)] }
                dueChip
                estimateChip
                toggleChip(.energy, isOn: task.needEnergy, tint: tokens.color(.energy)) { [.needEnergy(!task.needEnergy)] }
                toggleChip(.pleasant, isOn: task.pleasant == true, tint: tokens.color(.heart)) {
                    [.pleasant(task.pleasant != true)]
                }
                if !task.isHabit { statusChip }
                if !task.previousTasks.isEmpty || item.isBlocked {
                    Chip(icon: .previousTasks, text: "\(task.previousTasks.count)")
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.trailing, tokens.size(.reviewChevron))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .trailing) {
            Image(systemName: icons[.chevron]).foregroundStyle(tokens.color(.tertiaryText))
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
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

    /// Today / Tomorrow / an exact date and time; the chosen one is checked, choosing it again
    /// removes the date (no option checked = no date).
    private var dueChip: some View {
        let tomorrow = today.adding(days: 1)
        let isToday = task.due == TaskDue(day: today)
        let isTomorrow = task.due == TaskDue(day: tomorrow)
        return Menu {
            Toggle("due.today", isOn: Binding(get: { isToday }, set: { setDue($0 ? TaskDue(day: today) : nil) }))
            Toggle("due.tomorrow", isOn: Binding(get: { isTomorrow }, set: { setDue($0 ? TaskDue(day: tomorrow) : nil) }))
            Toggle("review.due.exact", isOn: Binding(get: { task.due != nil && !isToday && !isTomorrow },
                                                    set: { _ in isPickingDate = true }))
        } label: {
            Chip(icon: .due, text: task.due.map { DueText.format($0, today: today) }, isOn: task.due != nil)
        }
        .sheet(isPresented: $isPickingDate) {
            DueDateSheet(due: task.due ?? TaskDue(day: today, time: LocalTime(hour: 9, minute: 0))) { setDue($0) }
        }
    }

    private func setDue(_ due: TaskDue?) {
        Task { await model.update(task.name, [.due(due)]) }
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
