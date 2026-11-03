import Foundation

/// What is wrong with a task's data.
struct DayProblems: Sendable {
    let occurrence: TaskOccurrence

    func problems(of task: TaskItem) -> [TaskProblem] {
        occurrence.hasNoStart(task) ? task.problems + [.recurrenceWithoutStart] : task.problems
    }
}
