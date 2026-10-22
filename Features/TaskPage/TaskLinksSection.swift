import SwiftUI

/// Previous tasks (this task's `previous_task`) and Next tasks (tasks whose `previous_task`
/// contains this one). Each link is stored once, in the later task, and edited from both sides.
struct TaskLinksSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens
    let task: TaskNote
    @State private var picking: Side?

    enum Side: String, Identifiable {
        case previous
        case next
        var id: String { rawValue }
    }

    var body: some View {
        PlateSection(header: "taskPage.links", info: "info.taskPage.links") {
            linkGroup(.previous, icon: .previousTasks, title: "taskPage.previousTasks", names: task.previousTasks)
            linkGroup(.next, icon: .nextTasks, title: "taskPage.nextTasks", names: nextTasks)
        }
        .sheet(item: $picking) { side in
            TaskPickerScreen(excluded: Set([task.name]).union(side == .previous ? task.previousTasks : nextTasks)) { picked in
                add(picked, side: side)
            }
        }
    }

    private var nextTasks: [String] {
        model.tasks.filter { $0.previousTasks.contains(task.name) }.map(\.name).sorted()
    }

    @ViewBuilder private func linkGroup(_ side: Side, icon: Icon, title: LocalizedStringKey, names: [String]) -> some View {
        PlateRow(icon: icon, title: title) {
            Button { picking = side } label: { Image(systemName: icons[.add]) }
                .accessibilityLabel(Text("taskPage.addLink"))
                .accessibilityIdentifier("link.add.\(side.rawValue)")
        }
        ForEach(names, id: \.self) { name in
            HStack {
                NavigationLink(value: Route.task(name)) {
                    Text(name).foregroundStyle(model.task(named: name) == nil ? tokens.color(.problem) : tokens.color(.primaryText))
                }
                Spacer()
                Button { remove(name, side: side) } label: {
                    Image(systemName: icons[.remove]).foregroundStyle(tokens.color(.destructive))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("taskPage.removeLink"))
            }
            .padding(.leading, tokens.space(.childIndent))
        }
    }

    /// The link is always stored in the later task's `previous_task`.
    private func add(_ name: String, side: Side) {
        Task {
            switch side {
            case .previous: await model.update(task.name, [.addPreviousTask(name)])
            case .next: await model.update(name, [.addPreviousTask(task.name)])
            }
        }
    }

    private func remove(_ name: String, side: Side) {
        Task {
            switch side {
            case .previous: await model.update(task.name, [.removePreviousTask(name)])
            case .next: await model.update(name, [.removePreviousTask(task.name)])
            }
        }
    }
}

/// Previous event (do after it) and Next event (do before it).
struct TaskEventsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens
    let task: TaskNote
    @State private var picking: Field?

    enum Field: String, Identifiable {
        case previous
        case next
        var id: String { rawValue }
    }

    var body: some View {
        PlateSection(header: "taskPage.events", info: "info.taskPage.events", hint: "taskPage.events.hint") {
            row(.previous, icon: .previousEvent, title: "taskPage.previousEvent", link: task.previousEvent)
            row(.next, icon: .nextEvent, title: "taskPage.nextEvent", link: task.nextEvent)
        }
        .sheet(item: $picking) { field in
            EventPickerScreen { event in
                let link = EventLink(eventIdentifier: event.eventIdentifier, title: event.title, start: event.start)
                Task { await model.update(task.name, [field == .previous ? .previousEvent(link) : .nextEvent(link)]) }
            }
        }
    }

    @ViewBuilder private func row(_ field: Field, icon: Icon, title: LocalizedStringKey, link: EventLink?) -> some View {
        PlateRow(icon: icon, title: title) {
            Button { picking = field } label: { Image(systemName: icons[link == nil ? .add : .chevron]) }
                .accessibilityLabel(Text("taskPage.pickEvent"))
                .accessibilityIdentifier("event.pick.\(field.rawValue)")
        }
        if let link {
            let resolved = EventLinkResolver(events: model.events, calendar: model.calendar).resolve(link)
            HStack(spacing: tokens.space(.iconTextGap)) {
                if let resolved { SourceDot(hex: resolved.colorHex) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title)
                    Text(resolved == nil ? L10n.string("taskPage.eventNotFound")
                                         : (resolved?.start ?? link.start).formatted(date: .abbreviated, time: .shortened))
                        .font(tokens.font(.hint))
                        .foregroundStyle(resolved == nil ? tokens.color(.problem) : tokens.color(.secondaryText))
                }
                Spacer()
                Button {
                    Task { await model.update(task.name, [field == .previous ? .previousEvent(nil) : .nextEvent(nil)]) }
                } label: {
                    Image(systemName: icons[.remove]).foregroundStyle(tokens.color(.destructive))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("taskPage.removeLink"))
            }
            .padding(.leading, tokens.space(.childIndent))
        }
    }
}
