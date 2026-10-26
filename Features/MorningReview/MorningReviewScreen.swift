import SwiftUI

/// This week (the review): the pool as a table — one row per task with property chips edited in place, in
/// Morning, Day and Evening groups; rows reorder by dragging, also into another group (which sets their part
/// of the day). Until the first drag the order follows the automatic sort after every edit; after it the
/// manual order is kept for today. Reset sorting brings the sort back.
/// Tapping a row (outside its chips) opens the task page; "+" creates a new this-week task.
/// Swiping a row left takes it out of today: it stays this week and waits in "Not Today" at the bottom
/// (and in tomorrow's review); swiping it there to the right brings it back.
struct MorningReviewScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            let plan = model.plan(at: model.clock.now)
            List {
                Section {
                    let rows = ReviewGroups.rows(plan.pool)
                    let items = Dictionary(plan.pool.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                    ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                        switch row {
                        case .header(let group):
                            GroupHeaderRow(title: LocalizedStringKey("review.group." + group.rawValue))
                                .moveDisabled(true)
                                .accessibilityIdentifier("review.group.\(group.rawValue)")
                        case .item(let name):
                            if let item = items[name] {
                                let position = ReviewGroups.position(of: index, in: rows)
                                ReviewRow(item: item, today: plan.today) { path.append(.task(item.id)) }
                                    .groupRow(isFirst: position.isFirst, isLast: position.isLast)
                                    .accessibilityIdentifier("review:\(item.id)")
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button { Haptics.play(.light); model.postpone(item.id) } label: {
                                            Label("review.postpone", systemImage: icons[.postpone])
                                        }
                                        .tint(tokens.color(.swipeNeutral))
                                        .accessibilityIdentifier("review.postpone")
                                    }
                            }
                        }
                    }
                    .onMove { source, destination in
                        Haptics.play(.medium)
                        model.applyReviewMove(ReviewGroups.move(rows, from: source, to: destination, pool: plan.pool))
                    }
                } footer: {
                    Text(model.dayState.manualOrder == nil ? "review.footer.auto" : "review.footer.manual")
                        .accessibilityIdentifier("review.footer")
                }
                let postponed = model.postponedTasks
                if !postponed.isEmpty {
                    Section {
                        GroupHeaderRow(title: "review.postponed")
                        ForEach(Array(postponed.enumerated()), id: \.element.name) { index, task in
                            ReviewRow(item: DayItem(task: task, state: .open, blockers: [], problems: []), today: plan.today) {
                                path.append(.task(task.name))
                            }
                            .groupRow(isFirst: index == 0, isLast: index == postponed.count - 1)
                            .accessibilityIdentifier("review.notToday:\(task.name)")
                            .opacity(tokens.opacity(.blocked))
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { Haptics.play(.light); model.unpostpone(task.name) } label: {
                                    Label("review.backToToday", systemImage: icons[.restore])
                                }
                                .tint(tokens.color(.success))
                                .accessibilityIdentifier("review.backToToday")
                            }
                        }
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
                    Button {
                        model.resetOrder()
                        model.banners.show(L10n.string("banner.orderReset"))
                    } label: { Image(systemName: icons[.resetSort]) }
                    .accessibilityLabel(Text("review.reset"))
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

/// A group's title standing in the list as a row, so rows can be dragged across it.
private struct GroupHeaderRow: View {
    @Environment(\.tokens) private var tokens
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(tokens.font(.sectionHeader))
            .foregroundStyle(tokens.color(.tertiaryText))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
                if item.isBlocked { Image(systemName: icons[.links]).foregroundStyle(tokens.color(.secondaryText)) }
            }
            ChipFlow(spacing: tokens.space(.chipGap)) {
                toggleChip(.high, isOn: task.isHighPriority, tint: tokens.color(.high)) { [.highPriority(!$0.isHighPriority)] }
                dueChip
                estimateChip
                toggleChip(.energy, isOn: task.needEnergy, tint: tokens.color(.energy)) { [.needEnergy(!$0.needEnergy)] }
                toggleChip(.pleasant, isOn: task.pleasant == true, tint: tokens.color(.heart)) { [.pleasant($0.pleasant != true)] }
                if !task.isHabit { statusChip }
                if !task.previousTasks.isEmpty || item.isBlocked {
                    Chip(icon: .previousTasks, text: "\(task.previousTasks.count)")
                }
            }
        }
        .padding(.vertical, tokens.space(.reviewRowVertical))
        .padding(.trailing, tokens.size(.reviewChevron))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .trailing) { DisclosureAccessory() }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    /// The new value is decided from the note as it is when the edit runs (two quick taps go there and back).
    private func toggleChip(_ icon: Icon, isOn: Bool, tint: Color, changes: @escaping (TaskNote) -> [TaskFieldChange]) -> some View {
        Button {
            Haptics.play(.light)
            Task { await model.edit(task.name, changes) }
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
            Chip(icon: .due, text: task.due.map { DueText.format($0, today: today, calendar: model.calendar) }, isOn: task.due != nil)
        }
        .sheet(isPresented: $isPickingDate) {
            DueDateSheet(due: task.due ?? TaskDue(day: today, time: rules.editing.defaultTime), calendar: model.calendar) { setDue($0) }
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
