extension AccentCategory {
    /// The color of the elements of this kind: the accent the user picked while the category is on (`DesignTokens.applying`).
    var token: ColorToken {
        switch self {
        case .selects: .accentSelect
        case .toolbars: .accentToolbar
        case .calendar: .accentCalendar
        case .switches: .accentSwitch
        case .icons: .accentIcon
        case .checkmarks: .accentCheckmark
        case .buttons: .accentButton
        case .swipes: .accentSwipe
        case .dragMarks: .accentDragMark
        }
    }
}
