import SwiftUI

/// Timeline settings with a live preview. Stacked arrangement: one rolling column (hours
/// before/after) or two fixed halves; side by side: hours around now or the whole day.
/// Plus font sizes of events and tasks.
struct TimelineSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

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
            case .sideBySide:
                PlateRow(icon: .timelineLayout, title: "settings.timeline.range", info: "info.settings.timeline.range") {}
                Picker("settings.timeline.range", selection: binding(\.range)) {
                    Text("settings.timeline.aroundNow").tag(AppSettings.TimelineRange.aroundNow)
                    Text("settings.timeline.wholeDay").tag(AppSettings.TimelineRange.wholeDay)
                }
                .pickerStyle(.segmented)
            }
            switch model.settings.timelineMode {
            case .aroundNow:
                stepper(.hoursBefore, "settings.timeline.hoursBefore", "info.settings.timeline.hoursBefore", \.hoursBefore, 0...6)
                stepper(.hoursAfter, "settings.timeline.hoursAfter", "info.settings.timeline.hoursAfter", \.hoursAfter,
                        1...model.config.rules.timeline.maxHoursAfter)
            case .wholeDay:
                halfRow("settings.timeline.dayRange", \.wholeDay, info: "info.settings.timeline.dayRange")
            case .halves:
                halfRow("settings.timeline.firstHalf", \.firstHalf)
                halfRow("settings.timeline.secondHalf", \.secondHalf)
            }
            slider(.fontSize, "settings.timeline.eventFont", "info.settings.timeline.eventFont", \.eventFontSize)
            slider(.fontSize, "settings.timeline.taskFont", "info.settings.timeline.taskFont", \.taskFontSize)
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
            HStack(spacing: 4) {
                TimeField(time: binding(keyPath.appending(path: \.start)))
                Text(verbatim: "–")
                TimeField(time: binding(keyPath.appending(path: \.end)))
            }
        }
    }

    private func slider(_ icon: Icon, _ title: LocalizedStringKey, _ info: LocalizedStringKey,
                        _ keyPath: WritableKeyPath<AppSettings.Timeline, Double>) -> some View {
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            PlateRow(icon: icon, title: title, info: info) {
                Text(verbatim: "\(Int(model.settings.timeline[keyPath: keyPath])) pt").foregroundStyle(tokens.color(.secondaryText))
            }
            Slider(value: binding(keyPath), in: 11...22, step: 1)
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
        let height: CGFloat = 220
        Group {
            switch settings.timelineMode {
            case .aroundNow:
                ScrollView {
                    DayTimelineView(slots: plan.timeline,
                                    window: TimelineWindow.rolling(now: plan.now, hoursBefore: timeline.hoursBefore,
                                                                   hoursAfter: timeline.hoursAfter, calendar: model.calendar),
                                    now: plan.now, hourHeight: tokens.size(.hourHeight) * 0.6, style: style, taskContent: row)
                }
            case .wholeDay:
                let window = TimelineWindow.fixed(start: timeline.wholeDay.start, end: timeline.wholeDay.end,
                                                  context: model.context(at: plan.now))
                DayTimelineView(slots: plan.timeline, window: window, now: plan.now,
                                hourHeight: height / CGFloat(max(window.duration, 3600) / 3600), style: style, taskContent: row)
            case .halves:
                HalvesTimeline(plan: plan, settings: timeline, context: model.context(at: plan.now), height: height - 20,
                               taskContent: row)
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: tokens.radius(.timelineItem), style: .continuous))
        .accessibilityLabel(Text("settings.timeline.preview"))
    }

    private func row(_ item: DayItem, _ slot: TimelineSlot) -> some View {
        TaskRowView(item: item, today: plan.today, titleFont: .system(size: settings.timeline.taskFontSize), isCompact: true)
    }

    private var plan: DayPlan { model.plan(at: model.clock.now) }
}
