import Foundation

/// A problem tied to a task, for the problems badge and banners.
struct PlanProblem: Hashable, Sendable {
    let taskName: String
    let problem: TaskProblem
}
