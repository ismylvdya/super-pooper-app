import SwiftUI

/// What a hold of the page's title does (`searchOnTitleHold`), for its large title (`LargePageTitle`).
struct TitleHoldAction {
    let run: () -> Void
}

extension EnvironmentValues {
    @Entry var titleHold: TitleHoldAction?
}
