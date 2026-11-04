import SwiftUI
import UniformTypeIdentifiers

/// The user's own alarm sounds: an `.m4r` or any other audio file added here can be chosen like the others, as the default
/// too. Each can be removed; what used it rings with the system's sound then.
struct CustomAlarmSoundRows: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    @Environment(\.icons) private var icons
    @State private var isPicking = false
    @State private var sounds: [RulesConfig.Alarms.Sound] = []
    @State private var failed = false

    var body: some View {
        ForEach(sounds, id: \.id) { sound in
            PlateRow(icon: nil, title: Text(verbatim: sound.title), indent: true) {
                RemoveButton(label: "alarm.custom.remove") {
                    model.removeAlarmSound(sound.id)
                    reload()
                }
            }
        }
        Button { isPicking = true } label: {
            Label("alarm.custom.add", systemImage: icons[.add])
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("settings.notifications.addSound")
        .onAppear(perform: reload)
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [UTType(filenameExtension: "m4r") ?? .audio, .audio]) { result in
            guard case .success(let file) = result else { return }
            Task {
                failed = await model.addAlarmSound(from: file) == nil
                reload()
            }
        }
        .alert("alarm.custom.failed", isPresented: $failed) { Button("common.done") {} }
    }

    private func reload() { sounds = model.customAlarmSounds }
}
