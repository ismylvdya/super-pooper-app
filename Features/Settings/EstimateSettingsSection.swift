import SwiftUI

/// The four time estimates a task can have, each as many minutes as typed here.
struct EstimateSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    private let titles: [LocalizedStringKey] = ["settings.estimates.shortest", "settings.estimates.normal", "settings.estimates.long", "estimate.dohuya"]

    var body: some View {
        PlateSection(header: "settings.estimates", hint: "settings.estimates.hint") {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                PlateRow(icon: nil, title: title) {
                    TextField("settings.estimates.minutes", value: minutes(at: index), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(tokens.color(.secondaryText))
                        .accessibilityIdentifier("settings.estimates.\(index)")
                }
            }
        }
    }

    private func minutes(at index: Int) -> Binding<Int> {
        Binding(get: { model.settings.pool.estimateMinutes[safe: index] ?? 0 },
                set: { value in
                    guard value > 0 else { return }
                    model.updateSettings { settings in
                        if settings.pool.estimateMinutes.indices.contains(index) { settings.pool.estimateMinutes[index] = value }
                    }
                })
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
