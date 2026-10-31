import Foundation

/// Names of the design tokens in `tokens.json`. Screens never contain raw numbers or colors.
enum SpacingToken: String, CaseIterable, Sendable {
    case tabBarInner, landscapeBarInset, barButtonGap, reviewTop, popoverRowVertical, fadeGap, scrollEndRoom, listRowVertical
    case screenHorizontal, screenBottom, groupGap, plateInner, plateRowGap, headerToPlate, hintToPlate
    case iconTextGap, chipHorizontal, chipVertical, chipGap, infoPadding, nestedTitleInset, nestedTitleLift
    case childIndent, rowVertical, poolRowGap, blockGap, timelineLabelWidth, timelineItemGap, timelineItemPadding
    case bannerTop, bannerPadding, widgetPadding, habitCellGap, hourLabelGap, bellInset, liftShadow, toggleChipHorizontal, toggleChipVertical, titleInfoGap, chipIconGap, dotTextGap, valueChevronGap, reviewRowVertical, markPadding, badgeGap, progressGap, timelineTitleExtra, previewRowGap, titleDetailGap, footerLineGap, subtaskIndent
    case widgetGap, previewInset, cornerMarkGap, compactPlateVertical
}

enum RadiusToken: String, CaseIterable, Sendable {
    case plate, chip, timelineItem, banner, habitCell, notificationImage, previewItem, previewFrame
}

enum SizeToken: String, CaseIterable, Sendable {
    case iconColumn, checkbox, doneMark, infoMaxWidth, hourHeight, eventStripe, nowLine, nowDot, navTitleMin, notificationIcon
    case eventDot, sourceDot, fadeHeight, poolCounter, poolWidth
    case habitHistoryMaxHeight, habitStatsBar, titleFade, hourDigitsWidth, actionPopoverWidth, reviewChevron, wrapMinWidth, liftOverhang, pagePeek, dropLine, dropMarkerHeight, bannerShadowRadius, bannerShadowY, hexFieldWidth, progressHeight, gridLine, hourLabelHeight, widgetAllDayLine, allDayFontDelta, previewHeight, previewRow, previewPoolWidth, previewBlock, previewBlockTop, timelinePreviewHeight, timelinePreviewHalvesInset, subtaskDropLine, landscapeTabBarWidth, barButton
}

/// Shares and scale factors: a part of another size, not a size of its own.
enum RatioToken: String, CaseIterable, Sendable {
    case habitRing, habitPartialDot, infoMaxHeight, pullStartScale, pullArmedScale, timelinePreview, largeTitleVisible
}

enum OpacityToken: String, CaseIterable, Sendable {
    case blocked, past, eventFill, fadeTop, fadeMiddle, habitEmpty
    case gridFadedWeek, unlinked, eventTime, nowOverBlocks, daySwipeFade, toggleChipFill, bannerShadow, previewBlock
}

enum DurationToken: String, CaseIterable, Sendable {
    case animation, bannerAnimation, titleColorAnimation
}

enum FontToken: String, CaseIterable, Sendable {
    case pageTitle, navTitle, sectionHeader, rowTitle, hint, chip, info, timelineHour, banner, poolCounter
    case taskTitle, emptyTitle, emptyBody, footer, widgetTitle, widgetCaption, caption, noteEditor
    case statValue, toggleChip, pullIcon, emptyIcon, emptyAction, linkBadge, tabIcon, systemTabIcon, tabLabel, popoverAction, repeatableTitle, habitTitle
}

enum ColorToken: String, ConfigName {
    case accent, task, habit, high, energy, pleasant, heart, nowLine, problem
    case past, swipeNeutral, screenBackground, plateBackground, chipBackground, primaryText, secondaryText, tertiaryText
    case bannerBackground, infoText, destructive, eventText, timelineGrid
    case success, warning, error, shadow, widgetPlate, widgetTop, widgetBottom, listSeparator
}

/// The settings sections where the user picks colors (`editableColors`: which colors each offers, in order).
enum ColorSettingsGroup: String, CaseIterable, Sendable {
    case general, habits, widgets
}
