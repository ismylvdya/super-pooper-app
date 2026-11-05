import SwiftUI

/// What the chips and the date sheet do not set: a task's list, how it feels, its estimate and its tags. A habit's stand in
/// `HabitDaySection`.
struct TaskPropertiesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    let editor: TaskEditor

    private var task: TaskItem { editor.task }

    var body: some View {
        PlateSection(header: "taskPage.properties", info: "info.taskPage.properties") {
            listRow
            FeelPicker(feel: task.feel) { feel in
                Haptics.play(.select)
                editor.apply([.feel(feel)])
            }
            PlateRow(icon: .estimate, title: "taskPage.estimate", info: "info.taskPage.estimate") {
                Picker("taskPage.estimate", selection: estimateBinding) {
                    ForEach(rules.estimateOptions(including: rules.day.estimate(of: task)), id: \.minutes) { Text(LocalizedStringKey($0.label)).tag($0.minutes) }
                }
                .labelsHidden()
            }
            TaskTagsRow(task: task) { editor.apply([$0]) }
        }
    }

    /// The row shows the list's name alone, the menu each with its icon. An archived task's status has its own action in the "…"
    /// menu, and no place here.
    private var listRow: some View {
        PlateRow(icon: .status, title: "taskPage.list", info: "info.taskPage.status") {
            Menu {
                ForEach(TaskStatus.known, id: \.self) { status in
                    Toggle(isOn: Binding(get: { task.status == status },
                                         set: { _ in editor.setStatus(status, today: model.context().today) })) {
                        ListLabel(status: status)
                    }
                }
            } label: {
                AlarmSoundValue(shown: StatusText.title(task.status))
            }
            .accessibilityIdentifier("taskPage.list")
        }
    }

    private var estimateBinding: Binding<Int> {
        Binding(get: { rules.day.estimate(of: task) },
                set: { minutes in editor.apply([.timeEstimate(minutes)]) })
    }
}

/// Need energy, neutral in the middle, pleasant: the system's segmented control, with an icon for each.
private struct FeelPicker: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.displayScale) private var displayScale
    let feel: TaskFeel
    let onChange: (TaskFeel) -> Void

    var body: some View {
        PlateRow(icon: .feel, title: "taskPage.feel") {
            Picker("taskPage.feel", selection: Binding(get: { feel }, set: onChange)) {
                ForEach(TaskFeel.allCases, id: \.self) { feel in
                    image(of: feel).accessibilityLabel(Text(title(of: feel))).tag(feel)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: tokens.size(.feelPicker))
            .accessibilityIdentifier("taskPage.feel")
        }
    }

    /// In its own color: a segment draws a plain image in one tint.
    private func image(of feel: TaskFeel) -> Image {
        let font = tokens.uiFont(.toggleChip)
        let extent = font.capHeight * tokens.ratio(.handGlyph)
        let configuration = UIImage.SymbolConfiguration(font: font)
        let picture: UIImage?
        switch feel {
        case .needEnergy:
            picture = TemplateGlyph.image(icons[.energy], extent: extent, along: .vertical, scale: displayScale)?
                .withTintColor(UIColor(tokens.color(.energy)), renderingMode: .alwaysOriginal)
        case .neutral:
            picture = UIImage(systemName: icons[.feelNeutral], withConfiguration: configuration)
        case .pleasant:
            picture = UIImage(systemName: icons[.pleasant], withConfiguration: configuration)?
                .withTintColor(UIColor(tokens.color(.heart)), renderingMode: .alwaysOriginal)
        }
        return picture.map(Image.init(uiImage:)) ?? Image(systemName: icons[.feelNeutral])
    }

    private func title(of feel: TaskFeel) -> LocalizedStringKey {
        switch feel {
        case .needEnergy: "lists.energy"
        case .neutral: "taskPage.feel.neutral"
        case .pleasant: "lists.pleasant"
        }
    }
}

/// A list in the picker, with its icon (`TaskListIcons`).
private struct ListLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.displayScale) private var displayScale
    let status: TaskStatus

    var body: some View {
        Label {
            Text(StatusText.title(status))
        } icon: {
            let list = TaskListIcons(icons: icons, typed: model.settings.lists.symbols)
            TabIconImage.image(list.symbol(of: status), font: .preferredFont(forTextStyle: .body), others: list.symbols(besides: status),
                               matching: .width, fit: tokens.bar(.tabGlyphFit), scale: displayScale)
        }
    }
}

/// Started and Waiting, any of them: tags that leave the task in its list.
private struct TaskTagsRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    let task: TaskItem
    let onChange: (TaskEdit) -> Void

    var body: some View {
        PlateRow(icon: .tags, title: "taskPage.tags") {
            Menu {
                Toggle(isOn: Binding(get: { task.isStarted }, set: { onChange(.started($0)) })) {
                    Label {
                        Text("status.inProgress")
                    } icon: {
                        Image(model.config.actions.definition(.start).icon)
                    }
                }
                Toggle(isOn: Binding(get: { task.isWaiting }, set: { onChange(.waiting($0)) })) {
                    Label("status.waiting", systemImage: icons[.tagWaiting])
                }
            } label: {
                AlarmSoundValue(shown: shown)
            }
            .menuActionDismissBehavior(.disabled)
            .accessibilityIdentifier("taskPage.tags")
        }
    }

    private var shown: String {
        let tags = [task.isStarted ? "status.inProgress" : nil, task.isWaiting ? "status.waiting" : nil].compactMap { $0 }
        return tags.isEmpty ? L10n.string("taskPage.tags.none") : tags.map(L10n.string).joined(separator: ", ")
    }
}
