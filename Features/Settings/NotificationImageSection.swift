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
        PlateSection(header: "settings.notificationImage", hint: "settings.notificationImage.hint") {
            PlateRow(icon: nil, title: "settings.notificationImage.picture") {
                HStack(spacing: tokens.space(.iconTextGap)) {
                    preview
                    PhotosPicker(selection: $picked, matching: .images) { Text("settings.notificationImage.choose") }
                }
            }
            if image != nil {
                Button("settings.notificationImage.reset") {
                    image = nil
                    Task { await model.setNotificationImage(nil) }
                }
            }
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
