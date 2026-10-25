import SwiftUI

/// Timeline settings with a live preview. Stacked arrangement: one rolling column (hours
/// before/after) or two fixed halves; side by side: hours around now or the whole day.
/// Plus font sizes of events and tasks.
struct TimelineSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    private var limits: RulesConfig.Limits { model.config.rules.limits }

    var body: some View {
        PlateSection(header: "settings.timeline", info: "info.settings.timeline", hint: "settings.timeline.hint") {
            TimelinePreview(settings: model.settings)
            switch model.settings.today.arrangement {
            case .stacked:
                PlateRow(icon: .timelineLayout, title: "settings.timeline.layout", info: "info.settings.timeline.layout") {}
                Picker("settings.timeline.layout", selection: binding(\.layout)) {
                    Text("settings.timeline.oneColumn").tag(AppSettings.TimelineLayout.oneColumn)
                    Text("settings.timeline.twoColumns").tag(AppSettings.TimelineLayout.twoColumns)
                }
                .pickerStyle(.segmented)
            case .sideBySide, .paged:
                PlateRow(icon: .timelineLayout, title: "settings.timeline.range", info: "info.settings.timeline.range") {}
                Picker("settings.timeline.range", selection: binding(\.range)) {
                    Text("settings.timeline.aroundNow").tag(AppSettings.TimelineRange.aroundNow)
                    Text("settings.timeline.wholeDay").tag(AppSettings.TimelineRange.wholeDay)
                }
                .pickerStyle(.segmented)
            }
            switch model.settings.timelineMode {
            case .aroundNow:
                stepper(.hoursBefore, "settings.timeline.hoursBefore", "info.settings.timeline.hoursBefore", \.hoursBefore, limits.hoursBefore.ints)
                stepper(.hoursAfter, "settings.timeline.hoursAfter", "info.settings.timeline.hoursAfter", \.hoursAfter,
                        1...model.config.rules.timeline.maxHoursAfter)
            case .wholeDay:
                halfRow("settings.timeline.dayRange", \.wholeDay, info: "info.settings.timeline.dayRange")
            case .halves:
                halfRow("settings.timeline.firstHalf", \.firstHalf)
                halfRow("settings.timeline.secondHalf", \.secondHalf)
            }
            slider(.fontSize, "settings.timeline.eventFont", "info.settings.timeline.eventFont", \.eventFontSize, limits.fontSize)
            slider(.fontSize, "settings.timeline.taskFont", "info.settings.timeline.taskFont", \.taskFontSize, limits.fontSize)
            slider(.bell, "settings.timeline.bellSize", "info.settings.timeline.bell", \.bellSize, limits.bellSize)
            VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
                PlateRow(icon: .opacity, title: "settings.timeline.bellOpacity") {
                    Text(model.settings.timeline.bellOpacity.formatted(.percent.precision(.fractionLength(0))))
                        .foregroundStyle(tokens.color(.secondaryText))
                }
                Slider(value: binding(\.bellOpacity), in: limits.bellOpacity.closed, step: limits.bellOpacity.step ?? 0)
            }
            shownToggle(.event, "settings.timeline.showEvents", \.events)
            shownToggle(.reminder, "settings.timeline.showReminders", \.reminders)
            shownToggle(.time, "settings.timeline.showTasks", \.tasks)
            shownToggle(.habit, "settings.timeline.showHabits", \.habits)
        }
    }

    /// Hidden timed tasks and habits go back to the pool; hidden events and reminders are just not drawn.
    private func shownToggle(_ icon: Icon, _ title: LocalizedStringKey, _ keyPath: WritableKeyPath<TimelineFilter, Bool>) -> some View {
        PlateRow(icon: icon, title: title, info: "info.settings.timeline.shown") {
            Toggle(title, isOn: binding((\AppSettings.Timeline.shown).appending(path: keyPath))).labelsHidden()
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings.Timeline, Value>) -> Binding<Value> {
        Binding(get: { model.settings.timeline[keyPath: keyPath] },
                set: { value in model.updateSettings { $0.timeline[keyPath: keyPath] = value } })
    }

    private func stepper(_ icon: Icon, _ title: LocalizedStringKey, _ info: LocalizedStringKey,
                         _ keyPath: WritableKeyPath<AppSettings.Timeline, Int>, _ range: ClosedRange<Int>) -> some View {
        PlateRow(icon: icon, title: title, info: info, indent: true) {
            Stepper(value: binding(keyPath), in: range) {
                Text(L10n.format("settings.hours", model.settings.timeline[keyPath: keyPath]))
            }
            .fixedSize()
        }
    }

    private func halfRow(_ title: LocalizedStringKey, _ keyPath: WritableKeyPath<AppSettings.Timeline, AppSettings.TimeRange>,
                         info: LocalizedStringKey = "info.settings.timeline.halves") -> some View {
        PlateRow(icon: .halves, title: title, info: info, indent: true) {
            HStack(spacing: tokens.space(.titleInfoGap)) {
                TimeField(time: binding(keyPath.appending(path: \.start)))
                Text("common.dash")
                TimeField(time: binding(keyPath.appending(path: \.end)))
            }
        }
    }

    private func slider(_ icon: Icon, _ title: LocalizedStringKey, _ info: LocalizedStringKey,
                        _ keyPath: WritableKeyPath<AppSettings.Timeline, Double>, _ range: RulesConfig.Limits.Range) -> some View {
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            PlateRow(icon: icon, title: title, info: info) {
                Text(L10n.format("settings.points", Int(model.settings.timeline[keyPath: keyPath]))).foregroundStyle(tokens.color(.secondaryText))
            }
            Slider(value: binding(keyPath), in: range.closed, step: range.step ?? 1)
        }
    }
}

/// Live preview of the timeline with today's real data in a small frame.
struct TimelinePreview: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let settings: AppSettings

    var body: some View {
        let plan = model.plan(at: model.clock.now)
        let timeline = settings.timeline
        let style = TimelineStyle.make(timeline, tokens: tokens)
        let height = tokens.size(.timelinePreviewHeight)
        Group {
            switch settings.timelineMode {
            case .aroundNow:
                ScrollView {
                    DayTimelineView(slots: plan.timeline,
                                    window: TimelineWindow.rolling(now: plan.now, hoursBefore: timeline.hoursBefore,
                                                                   hoursAfter: timeline.hoursAfter, calendar: model.calendar),
                                    now: plan.now, hourHeight: tokens.size(.hourHeight) * tokens.size(.timelinePreviewScale), style: style, taskContent: row)
                }
            case .wholeDay:
                let window = TimelineWindow.fixed(start: timeline.wholeDay.start, end: timeline.wholeDay.end,
                                                  context: model.context(at: plan.now))
                DayTimelineView(slots: plan.timeline, window: window, now: plan.now,
                                hourHeight: CGFloat(window.hourHeight(fitting: Double(height))), style: style, taskContent: row)
            case .halves:
                HalvesTimeline(plan: plan, settings: timeline, context: model.context(at: plan.now), height: height - tokens.size(.timelinePreviewHalvesInset),
                               taskContent: row)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: tokens.radius(.timelineItem), style: .continuous))
        .settingsPreviewFrame()
        .accessibilityLabel(Text("settings.timeline.preview"))
    }

    private func row(_ item: DayItem, _ slot: TimelineSlot) -> some View {
        TaskRowView(item: item, today: plan.today, titleFont: .system(size: settings.timeline.taskFontSize), showsDetails: false,
                    titleLineLimit: 2, titleLineHeight: UIFont.systemFont(ofSize: settings.timeline.taskFontSize).lineHeight)
    }

    private var plan: DayPlan { model.plan(at: model.clock.now) }
}
