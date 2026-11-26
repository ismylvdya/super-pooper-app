import Foundation

/// Amounts are averaged over recorded days. An explicit zero counts as a record.
struct HabitQuantityStats {
    let recordedDays: Int
    let total: Double
    let average: Double?
    let maximum: Int?

    init(_ quantities: [LocalDate: Int], through today: LocalDate) {
        let amounts = quantities.filter { $0.key <= today }.values
        recordedDays = amounts.count
        total = amounts.reduce(0) { $0 + Double($1) }
        average = recordedDays == 0 ? nil : total / Double(recordedDays)
        maximum = amounts.max()
    }
}
