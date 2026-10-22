import SwiftUI

/// Every data problem in one list (broken YAML, missing links, unknown rules…). Problems are
/// shown here and as a badge, never as pushes.
struct ProblemsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Button {
                        guard let task = line.taskName, model.task(named: task) != nil else { return }
                        dismiss()
                        router.open(.task(task))
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.title).foregroundStyle(tokens.color(.primaryText))
                                Text(line.detail).font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
                            }
                        } icon: {
                            Image(systemName: icons[.problem]).foregroundStyle(tokens.color(.problem))
                        }
                    }
                }
            }
            .overlay { if lines.isEmpty { Text("problems.none").foregroundStyle(tokens.color(.secondaryText)) } }
            .navigationTitle(Text("problems.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
        }
    }

    private struct Line {
        let taskName: String?
        let title: String
        let detail: String
    }

    private var lines: [Line] {
        let files = model.fileProblems.map { problem -> Line in
            switch problem {
            case .brokenYAML(let file, let reason): Line(taskName: nil, title: file, detail: L10n.format("problem.brokenYAML", reason))
            case .notDownloaded(let file): Line(taskName: nil, title: file, detail: L10n.string("problem.notDownloaded"))
            case .unreadable(let file, let reason): Line(taskName: nil, title: file, detail: L10n.format("problem.unreadable", reason))
            case .tasksFolderMissing(let folder): Line(taskName: nil, title: folder, detail: L10n.string("problem.folderMissing"))
            }
        }
        let tasks = model.plan(at: model.clock.now).problems.map { Line(taskName: $0.taskName, title: $0.taskName, detail: ProblemText.describe($0.problem)) }
        return files + tasks
    }
}

enum ProblemText {
    static func describe(_ problem: TaskProblem) -> String {
        switch problem {
        case .unknownRecurrence(let rule): L10n.format("problem.unknownRecurrence", rule)
        case .invalidField(let key, let value): L10n.format("problem.invalidField", key, value)
        case .linkedTaskNotFound(let name): L10n.format("problem.linkNotFound", name)
        case .eventNotFound(let title): L10n.format("problem.eventNotFound", title)
        case .dependencyCycle: L10n.string("problem.cycle")
        }
    }
}
