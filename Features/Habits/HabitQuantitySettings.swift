import SwiftUI

/// Configure the range of amounts independently of the daily entry control.
struct HabitQuantitySettings: View {
    let quantity: HabitQuantity
    let limit: Int
    let save: (HabitQuantity) -> Void

    var body: some View {
        PlateRow(icon: nil, title: "habitPage.quantity.maximum") {
            Stepper(value: Binding(get: { quantity.maximum }, set: { maximum in
                save(HabitQuantity(maximum: maximum, step: min(quantity.step, maximum)))
            }), in: HabitQuantity.minimum...max(limit, quantity.maximum)) {
                Text(verbatim: L10n.format("common.range", HabitQuantity.minimum.formatted(.number), quantity.maximum.formatted(.number)))
            }
            .fixedSize()
        }
        PlateRow(icon: nil, title: "habitPage.quantity.step") {
            number(quantity.step, in: 1...quantity.maximum) { step in
                save(HabitQuantity(maximum: quantity.maximum, step: step))
            }
        }
    }

    private func number(_ value: Int, in range: ClosedRange<Int>, save: @escaping (Int) -> Void) -> some View {
        Stepper(value: Binding(get: { value }, set: save), in: range) {
            Text(value, format: .number)
        }
        .fixedSize()
    }
}
