import Foundation

/// Names of the design tokens in `tokens.json`. Screens never contain raw numbers or colors.
enum SpacingToken: String, CaseIterable, Sendable {
    case screenHorizontal, screenBottom, groupGap, plateInner, plateRowGap, headerToPlate, hintToPlate
    case iconTextGap, chipHorizontal, chipVertical, chipGap, infoPadding, nestedTitleInset, nestedTitleLift
    case childIndent, rowVertical, poolRowGap, blockGap, timelineLabelWidth, timelineItemGap, timelineItemPadding
    case bannerTop, bannerPadding, widgetPadding, habitCellGap, titleBottom
}

enum RadiusToken: String, CaseIterable, Sendable {
    case plate, chip, timelineItem, banner, poolRow, habitCell, widgetItem
}

enum SizeToken: String, CaseIterable, Sendable {
    case iconColumn, checkbox, infoMaxWidth, hourHeight, eventStripe, nowLine, nowDot, navTitleMin, navTitleStep
    case problemDot, sourceDot, habitCell, fadeHeight, bannerLines, poolRowEstimate, poolCounter, poolWidth
}

enum OpacityToken: String, CaseIterable, Sendable {
    case blocked, past, eventFill, taskFill, doneText, fadeTop, fadeMiddle, habitEmpty, partialFill
}

enum DurationToken: String, CaseIterable, Sendable {
    case bannerAutoHide, animation, bannerAnimation, titleColorAnimation
}

enum FontToken: String, CaseIterable, Sendable {
    case pageTitle, navTitle, sectionHeader, rowTitle, hint, chip, info, timelineHour, banner, poolCounter
    case taskTitle, emptyTitle, emptyBody, footer, widgetTitle, widgetCaption, caption, noteEditor
}

enum ColorToken: String, CaseIterable, Sendable {
    case accent, task, habit, high, energy, pleasant, unpleasant, nowLine, problem, partial, twice
    case past, screenBackground, plateBackground, chipBackground, primaryText, secondaryText, tertiaryText
    case separator, bannerBackground, infoText, destructive, habitEmpty, eventText, timelineGrid
}
