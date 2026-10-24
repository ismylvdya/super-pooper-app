import SwiftUI
import UIKit

extension Image {
    /// An icon from icons.json: an SF Symbol, or a template image of the asset catalog (the habit marks).
    init(icon: Icon, icons: IconSet) {
        let name = icons[icon]
        if UIImage(systemName: name) != nil {
            self.init(systemName: name)
        } else {
            self.init(name)
        }
    }
}
