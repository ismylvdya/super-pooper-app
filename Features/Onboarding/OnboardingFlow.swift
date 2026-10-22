import SwiftUI

/// First launch, step by step: vault folder → Calendar → Reminders → notifications → anchor
/// calendars and reminder lists. Every step is also available later in Settings.
struct OnboardingFlow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @State private var step = Step.vault
    @State private var isPickingVault = false

    enum Step: Int, CaseIterable {
        case vault, calendar, reminders, notifications, sources
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: tokens.space(.groupGap)) {
                progress
                Spacer()
                content
                Spacer()
                buttons
            }
            .padding(.horizontal, tokens.space(.screenHorizontal))
            .padding(.bottom, tokens.space(.screenBottom))
            .background(tokens.color(.screenBackground))
            .vaultPicker(isPresented: $isPickingVault)
            .task { await model.refreshAccess() }
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? tokens.color(.accent) : tokens.color(.chipBackground))
                    .frame(height: 4)
            }
        }
        .padding(.top, tokens.space(.groupGap))
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .vault:
            OnboardingStep(icon: .vault, title: "onboarding.vault.title", message: "onboarding.vault.message",
                           status: model.vaultName, action: "vault.choose") { isPickingVault = true }
        case .calendar:
            OnboardingStep(icon: .calendars, title: "onboarding.calendar.title", message: "onboarding.calendar.message",
                           status: model.access.calendars == .granted ? L10n.string("onboarding.granted") : nil,
                           action: "settings.access.allow") { Task { await model.requestCalendarAccess() } }
        case .reminders:
            OnboardingStep(icon: .reminderLists, title: "onboarding.reminders.title", message: "onboarding.reminders.message",
                           status: model.access.reminders == .granted ? L10n.string("onboarding.granted") : nil,
                           action: "settings.access.allow") { Task { await model.requestRemindersAccess() } }
        case .notifications:
            OnboardingStep(icon: .notifications, title: "onboarding.notifications.title", message: "onboarding.notifications.message",
                           status: model.access.notifications == .granted ? L10n.string("onboarding.granted") : nil,
                           action: "settings.access.allow") { Task { await model.requestNotificationAccess() } }
        case .sources:
            VStack(spacing: tokens.space(.groupGap)) {
                OnboardingStep(icon: .event, title: "onboarding.sources.title", message: "onboarding.sources.message",
                               status: nil, action: nil) {}
                Plate {
                    NavigationLink { SourcePickerScreen(kind: .calendars) } label: {
                        PlateRow(icon: .calendars, title: "settings.calendars") {
                            Text(verbatim: "\(model.settings.sources.anchorCalendarIDs.count)")
                        }
                    }
                    .disabled(model.access.calendars != .granted)
                    NavigationLink { SourcePickerScreen(kind: .reminderLists) } label: {
                        PlateRow(icon: .reminderLists, title: "settings.reminderLists") {
                            Text(verbatim: "\(model.settings.sources.reminderListIDs.count)")
                        }
                    }
                    .disabled(model.access.reminders != .granted)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var buttons: some View {
        HStack {
            if step != .vault {
                Button("onboarding.back") { withAnimation { step = Step(rawValue: step.rawValue - 1) ?? .vault } }
            }
            Spacer()
            Button(step == .sources ? "onboarding.start" : "onboarding.next") {
                if let next = Step(rawValue: step.rawValue + 1) {
                    withAnimation { step = next }
                } else {
                    model.updateSettings { $0.onboarding.completed = true }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(tokens.color(.accent))
        }
    }
}

struct OnboardingStep: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let icon: Icon
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let status: String?
    let action: LocalizedStringKey?
    let perform: () -> Void

    var body: some View {
        VStack(spacing: tokens.space(.plateRowGap)) {
            Image(systemName: icons[icon]).font(.system(size: 52)).foregroundStyle(tokens.color(.accent))
            Text(title).font(tokens.font(.emptyTitle)).multilineTextAlignment(.center)
            Text(message).font(tokens.font(.emptyBody)).foregroundStyle(tokens.color(.secondaryText)).multilineTextAlignment(.center)
            if let status {
                Label(status, systemImage: icons[.permissionGranted]).foregroundStyle(tokens.color(.pleasant))
            } else if let action {
                Button(action: perform) { Text(action).fontWeight(.semibold) }.buttonStyle(.bordered)
            }
        }
    }
}
