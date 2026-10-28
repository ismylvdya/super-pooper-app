import PhotosUI
import SwiftUI

/// The picture at the right of habit notifications: the habit symbol in the habits' color, or a picture of the
/// user's own from Photos (kept on this device).
struct NotificationImageSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @State private var picked: PhotosPickerItem?
    @State private var image: UIImage?

    var body: some View {
        let isShown = model.settings.habits.showsNotificationPicture
        PlateSection(header: "settings.notificationImage", hint: "settings.notificationImage.hint") {
            PlateRow(icon: nil, title: "settings.notificationImage.show") {
                Toggle("settings.notificationImage.show", isOn: Binding(
                    get: { isShown },
                    set: { value in
                        model.updateSettings { $0.habits.showsNotificationPicture = value }
                        Task { await model.rescheduleNotifications(context: model.context()) }
                    }
                ))
                .labelsHidden()
            }
            // The rows below appear only while the picture is shown.
            if isShown { pictureRows }
        }
        .onAppear { image = model.notificationImageData.flatMap(UIImage.init(data:)) }
        .onChange(of: picked) {
            guard let picked else { return }
            Task {
                guard let data = try? await picked.loadTransferable(type: Data.self) else { return }
                await model.setNotificationImage(data)
                image = model.notificationImageData.flatMap(UIImage.init(data:))
                self.picked = nil
            }
        }
    }

    @ViewBuilder private var pictureRows: some View {
        PlateRow(icon: nil, title: "settings.notificationImage.picture") {
            HStack(spacing: tokens.space(.iconTextGap)) {
                preview
                PhotosPicker(selection: $picked, matching: .images) { Text("settings.notificationImage.choose") }
            }
        }
        PlateRow(icon: nil, title: "settings.notificationImage.habitColor", info: "info.settings.notificationImage.habitColor") {
            Toggle("settings.notificationImage.habitColor", isOn: Binding(
                get: { model.settings.habits.notificationUsesHabitColor },
                set: { value in
                    model.updateSettings { $0.habits.notificationUsesHabitColor = value }
                    Task { await model.rescheduleNotifications(context: model.context()) }
                }
            ))
            .labelsHidden()
        }
        // Only the habit symbol has a color; one's own picture shows as it is.
        .disabled(image != nil)
        .opacity(image != nil ? tokens.opacity(.blocked) : 1)
        if image != nil {
            Button("settings.notificationImage.reset") {
                image = nil
                Task { await model.setNotificationImage(nil) }
            }
        }
    }

    @ViewBuilder private var preview: some View {
        let side = tokens.size(.iconColumn)
        if let image {
            Image(uiImage: image).resizable().scaledToFill().frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: tokens.radius(.widgetItem), style: .continuous))
        } else {
            Image(systemName: icons[.habit]).foregroundStyle(tokens.color(.habit)).frame(width: side, height: side)
        }
    }
}
