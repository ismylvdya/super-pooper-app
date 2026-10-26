import Foundation

/// Names of the design tokens in `tokens.json`. Screens never contain raw numbers or colors.
enum SpacingToken: String, CaseIterable, Sendable {
    case tabBarInner, landscapeBarInset, barButtonGap, todayBarTop, todayBarBottom
    case screenHorizontal, screenBottom, groupGap, plateInner, plateRowGap, headerToPlate, hintToPlate
    case iconTextGap, chipHorizontal, chipVertical, chipGap, infoPadding, nestedTitleInset, nestedTitleLift
    case childIndent, rowVertical, poolRowGap, blockGap, timelineLabelWidth, timelineItemGap, timelineItemPadding
    case bannerTop, bannerPadding, widgetPadding, habitCellGap, hourLabelGap, bellInset, liftShadow, listRowInset, toggleChipHorizontal, toggleChipVertical, titleInfoGap, chipIconGap, dotTextGap, valueChevronGap, reviewRowVertical, markPadding, badgeGap, progressGap, linkBadgeTrailing, timelineTitleExtra, previewRowGap, titleDetailGap, footerLineGap, subtaskIndent
}

enum RadiusToken: String, CaseIterable, Sendable {
    case plate, chip, timelineItem, banner, poolRow, habitCell, widgetItem, previewItem
}

enum SizeToken: String, CaseIterable, Sendable {
    case iconColumn, checkbox, doneMark, infoMaxWidth, hourHeight, eventStripe, nowLine, nowDot, navTitleMin
    case problemDot, sourceDot, fadeHeight, bannerLines, poolRowEstimate, poolCounter, poolWidth
    case habitRingRatio, habitPartialDot, habitHistoryMaxHeight, habitStatsBar, infoMaxHeightRatio, linkBadge, titleFade, hourDigitsWidth, pullThreshold, pullIcon, actionPopoverWidth, daySwipeStart, reviewChevron, timelineZoomMin, timelineZoomMax, wrapMinWidth, narrowFadeShift, liftOverhang, pagePeek, dropLine, dropMarkerHeight, screenHeightEstimate, bannerShadowRadius, bannerShadowY, bannerDismissDistance, bannerDismissFling, tapSlop, hexFieldWidth, pullArmedScale, pullStartScale, daySwipeAxisRatio, progressHeight, gridLine, hourLabelHeight, widgetAllDayLine, allDayFontDelta, previewHeight, previewRow, previewRows, previewHours, previewPoolWidth, previewBlock, previewBlockTop, timelinePreviewHeight, timelinePreviewScale, timelinePreviewHalvesInset, subtaskDropLine, landscapeTabBarWidth, barButton
}

enum OpacityToken: String, CaseIterable, Sendable {
    case blocked, past, eventFill, fadeTop, fadeMiddle, habitEmpty
    case gridFadedWeek, unlinked, eventTime, nowOverBlocks, daySwipeThreshold, daySwipeFade, toggleChipFill, bannerShadow, previewBlock, largeTitleVisible
}

enum DurationToken: String, CaseIterable, Sendable {
    case bannerAutoHide, animation, bannerAnimation, titleColorAnimation
}

enum FontToken: String, CaseIterable, Sendable {
    case pageTitle, navTitle, sectionHeader, rowTitle, hint, chip, info, timelineHour, banner, poolCounter
    case taskTitle, emptyTitle, emptyBody, footer, widgetTitle, widgetCaption, caption, noteEditor
    case statValue, toggleChip, pullIcon, emptyIcon, emptyAction, linkBadge, tabIcon, tabLabel, habitTitle
}

enum ColorToken: String, CaseIterable, Sendable {
    case accent, task, habit, high, energy, pleasant, heart, nowLine, problem, twice
    case past, swipeNeutral, screenBackground, plateBackground, chipBackground, primaryText, secondaryText, tertiaryText
    case bannerBackground, infoText, destructive, eventText, timelineGrid
    case missed, success, warning, error, shadow, widgetPlate
}
