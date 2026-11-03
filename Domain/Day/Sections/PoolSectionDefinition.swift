import Foundation

/// One of the sections every day's pool starts with (`rules.json` → `pool.defaultSections`): its routine's habits go
/// there, and exactly one of them takes everything else.
struct PoolSectionDefinition: Codable, Hashable, Sendable {
    let id: String
    /// A text key.
    let title: String
    var routine: HabitTimeOfDay?
    var catchesRest = false

    init(id: String, title: String, routine: HabitTimeOfDay? = nil, catchesRest: Bool = false) {
        self.id = id
        self.title = title
        self.routine = routine
        self.catchesRest = catchesRest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        routine = try container.decodeIfPresent(HabitTimeOfDay.self, forKey: .routine)
        catchesRest = try container.decodeIfPresent(Bool.self, forKey: .catchesRest) ?? false
    }
}

extension [PoolSectionDefinition] {
    /// The section that takes what no routine and no snapshot places; `validate` made sure there is one.
    var restID: String { first(where: \.catchesRest)?.id ?? first?.id ?? "" }

    /// The default section of a routine's habits.
    func id(for routine: HabitTimeOfDay?) -> String? {
        routine.flatMap { routine in first { $0.routine == routine }?.id }
    }

}
