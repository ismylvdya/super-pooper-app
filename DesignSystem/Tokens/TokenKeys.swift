import Foundation

/// Names of the design tokens in `tokens.json`. Screens never contain raw numbers or colors.
enum SpacingToken: String, CaseIterable, Sendable {
    case reviewTop, fadeGap, scrollEndRoom, listRowVertical
    case screenHorizontal, screenBottom, groupGap, plateInner, plateRowGap, headerToPlate, hintToPlate
    case iconTextGap, searchFieldInset, chipHorizontal, chipVertical, chipGap, dayArrowGap, pagesGap, backlogPeek, infoPadding, nestedTitleInset, nestedTitleLift
    case childIndent, rowVertical, poolRowGap, blockGap, timelineLabelWidth, allDayTitleGap, timelineItemGap, timelineItemPadding
    case bannerPadding, widgetMargin, habitCellGap, hourLabelGap, bellInset, liftShadow, toggleChipHorizontal, toggleChipVertical, titleInfoGap, chipIconGap, dotTextGap, valueChevronGap, reminderRingGap, menuValueInset, menuValueVertical, reviewRowVertical, markPadding, badgeGap, progressGap, timelineTitleExtra, previewRowGap, titleDetailGap, footerLineGap
    case widgetGap, previewInset, cornerMarkGap, compactPlateVertical, emptyStateInset, widgetGridGap
    /// How much further right a timeline block lying over an earlier one starts, per step.
    case timelineCascadeIndent
    /// What a stack of dragged tasks shows of each plate under the top one.
    /// An event's stripe: from the plate's edges, and to the text.
    case eventStripeInset, eventStripeGap
    /// Between a swipe button's symbol and its title.
    case swipeIconTitleGap
    /// Between the priority icon before a high-priority task's name and the name.
    case priorityIconGap
    /// A section header starts this far right of the plates' left edge; a pool section's header stands this far below
    /// the section above.
    case sectionHeaderInset, poolSectionGap
    /// Between the name of a task shown one at a time and its next action's name under it.
    case projectCaptionGap
    /// How far below the banner on top each banner under it peeks out.
    case bannerStackPeek
}

enum RadiusToken: String, CaseIterable, Sendable {
    case plate, chip, timelineItem, habitCell, notificationImage, previewItem, previewFrame
}

enum SizeToken: String, CaseIterable, Sendable {
    /// The outline of a row picked in Select mode.
    case selectionOutline
    case iconColumn, checkbox, doneMark, infoMaxWidth, hourHeight, eventStripe, nowLine, nowDot, navTitleMin, notificationIcon
    case dayArrowTarget
    case habitDotMinimum, cornerInsetMinimum, sourceDot, fadeHeight, poolCounter, poolWidth
    case habitHistoryMaxHeight, habitStatsBar, habitStatsBarMin, habitMonthBar, habitMonthBarMin, titleFade, allDayIconScale, dragBadge, alarmMark, feelPicker, reminderRing, reminderRingStroke, rowIconHeight, reviewChevron, wrapMinWidth, liftOverhang, pagePeek, dropMarkerHeight, bannerShadowRadius, bannerShadowY, hexFieldWidth, progressHeight, gridLine, hourLabelHeight, widgetAllDayLine, previewHeight, previewRow, previewPoolWidth, previewBlock, previewBlockTop, timelinePreviewHeight, timelinePreviewHalvesInset, subtaskDropLine
    /// How thick the lines from a parent to its subtasks are.
    case subtaskLine
    /// The problems badge on Today's Lists button: its smallest width and its height.
    case problemBadge
    /// Room added above and below a date found in a new task's name, so a tap on it lands easily.
    case detectedDateTapRoom
}

/// Shares and scale factors: a part of another size, not a size of its own.
enum RatioToken: String, CaseIterable, Sendable {
    case habitRing, habitPartialDot, infoMaxHeight, pullStartScale, pullArmedScale, timelinePreview, largeTitleVisible
    case fadeMiddleStop, widgetWrappedTitle
    /// A hand-drawn glyph standing in a line of text (the frog of Need energy): how tall its ink is, in cap heights of
    /// the text's font, as the wide SF Symbols (the heart, the warning triangle) stand there.
    case handGlyph
    /// The room a timeline block's title needs under its top, in its minimum heights: a block starting closer under it
    /// stands beside it rather than over it.
    case timelineTitleRoom
    /// How much of a row's height a swipe button's symbol and title take together at most.
    case swipeGlyphFit
    /// How much narrower each banner under the top one of the stack is.
    case bannerStackShrink
    /// The line into the room a "+" makes for a subtask fades out this many indents right of where it comes down.
    case subtaskLineFade
    /// How much narrower each plate under the top one of a dragged stack is.
}

/// How many of something a drawing has (lines of a wrapped title).
enum CountToken: String, CaseIterable, Sendable {
    case widgetTitleLines
    /// Banners of the stack drawn at once, the top one with those under it.
    case bannerStack
}

enum OpacityToken: String, CaseIterable, Sendable {
    case blocked, past, selectionOutline, eventFill, eventFillDark, eventTitleLightMix, eventTimeLightMix, eventTitleDark, eventTimeDark, fadeTop, fadeMiddle, habitEmpty
    /// The ring of a habit's day not done or done partly (the user's `habits.ringOpacity` over it).
    case habitOpenRing
    case gridFadedWeek, unlinked, eventTime, nowOverBlocks, daySwipeFade, toggleChipFill, bannerShadow, previewBlock, accentedPlate, signingPlate
    /// The faint copy of a dragged plate where it would land (the pool's parted gap, the timeline's landing spot).
    case dropGhost
    /// The ":15", ":30", ":45" of a zoomed-in timeline and its five-minute lines, at their full fade-in.
    case quarterLabel, fineLine
    /// The soft red of a high-priority task's plate (Settings → Pool → High priority → Fill).
    case highPriorityFill
}

enum DurationToken: String, CaseIterable, Sendable {
    case keyboardAfterPush, animation, bannerAnimation, titleColorAnimation, titleSwap
}

enum FontToken: String, CaseIterable, Sendable {
    case pageTitle, navTitle, sectionHeader, rowTitle, hint, chip, info, timelineHour, banner, poolCounter
    case taskTitle, emptyTitle, emptyBody, footer, widgetTitle, widgetCaption, widgetEvent, caption, noteEditor
    case statValue, statSubheading, toggleChip, pullIcon, emptyIcon, emptyAction, linkBadge, repeatableTitle, habitTitle, timelineMinutes
    /// The timeline at the sizes picked in settings (`font(_:size:)`).
    case timelineText
    /// A swipe button's symbol and the title under it, drawn inside the button.
    case swipeIcon, swipeTitle
    /// The name of a task shown one at a time, over its next action's in the pool.
    case projectCaption
}

enum ColorToken: String, ConfigName {
    /// The outline of a row picked in Select mode: between a section's title and the text.
    case selectionOutline
    case accent, tabBar, tabBarPick, switchOn, task, habit, high, started, energy, pleasant, heart, alarmButton, alarmButtonText, overdue, energyOnFill, heartOnFill, eventIconGlyph, nowLine, problem
    case past, swipeNeutral, screenBackground, plateBackground, chipBackground, primaryText, secondaryText, tertiaryText
    case bannerBackground, infoText, destructive, timelineGrid
    case success, warning, error, shadow, widgetPlate, widgetTop, widgetBottom, listSeparator
    case signingAhead, signingSoon, signingUrgent
    /// A date found in a new task's name.
    case detectedDate
    /// The title of a section (settings groups, the pool's sections).
    case sectionHeader
    /// The thin lines from a parent to its subtasks in the pool.
    case subtaskLine
}

/// The settings sections where the user picks colors (`editableColors`: which colors each offers, in order).
enum ColorSettingsGroup: String, CaseIterable, Sendable {
    case general, tasks, habits, widgets
}

/// Letters a drawing is measured by.
enum GlyphToken: String, CaseIterable, Sendable {
    /// The line from a parent to its subtasks stands under the middle of this letter at the start of the parent's name.
    case subtaskLine
}
