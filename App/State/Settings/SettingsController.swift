import Foundation
import Observation

/// What follows a settings change once the changes stop (the sync service).
@MainActor
protocol SettingsObserver: AnyObject {
    func settingsDidChange(from old: AppSettings) async
}

/// The app's settings. The screens see a change at once; the settings file is written, and what the change brings is
/// worked out, once the changes stop (a slider sends one per step). The synced part is kept in step with the vault's
/// settings note (another device, Obsidian).
@MainActor
@Observable
final class SettingsController {
    private(set) var settings: AppSettings
    @ObservationIgnored weak var observer: SettingsObserver?
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let note: SettingsNoteRepository
    @ObservationIgnored private let rules: RulesConfig
    @ObservationIgnored private let delay: Delay
    /// The settings file write and what the change brings, waiting for the changes to stop.
    @ObservationIgnored private var save: Task<Void, Never>?
    /// The settings before the changes still waiting there; nil when nothing waits.
    @ObservationIgnored private var beforeSave: AppSettings?
    @ObservationIgnored private var noteWrite: Task<Void, Never>?
    /// A change not written to the vault note yet.
    @ObservationIgnored private var notePending = false

    init(store: SettingsStore, note: SettingsNoteRepository, rules: RulesConfig, delay: Delay) {
        self.store = store
        self.note = note
        self.rules = rules
        self.delay = delay
        settings = store.load()
    }

    func update(_ change: (inout AppSettings) -> Void) {
        let old = settings
        change(&settings)
        guard settings != old else { return }
        if SyncedSettings(old) != SyncedSettings(settings) { scheduleNoteWrite() }
        scheduleSave(from: old)
    }

    /// A change still waiting is written and followed now (the app goes to the background, a setting the notifications
    /// draw from the file).
    func flush() async {
        guard beforeSave != nil else { return }
        save?.cancel()
        await saveNow()
    }

    /// The file only, for a sync that reads the folder and the calendars from it; the rest follows after the wait.
    func writeWaiting() {
        guard beforeSave != nil else { return }
        try? store.save(settings)
    }

    /// Returns once the waiting change is written and followed.
    func waitForSave() async {
        await save?.value
    }

    /// The vault's settings note wins over this device, after this device's unwritten change went there; the first
    /// time, this device writes it.
    func syncWithVaultNote() async {
        await flushNote()
        if let json = await note.read() {
            apply(note: json)
        } else if let json = try? JSONEncoder.store.encode(SyncedSettings(settings)) {
            try? await note.write(json)
        }
    }

    /// Settings changed in the vault note come in without being written back.
    private func apply(note json: Data) {
        let old = settings
        let merged = SyncedSettings.merged(note: json, over: settings)
        guard merged != old else { return }
        settings = merged
        try? store.save(settings)
        Task { await observer?.settingsDidChange(from: old) }
    }

    private func scheduleSave(from old: AppSettings) {
        if beforeSave == nil { beforeSave = old }
        save?.cancel()
        save = Task {
            try? await delay.wait(rules.editing.settingsSaveDelaySeconds)
            guard !Task.isCancelled else { return }
            await saveNow()
        }
    }

    private func saveNow() async {
        guard let old = beforeSave else { return }
        beforeSave = nil
        try? store.save(settings)
        await observer?.settingsDidChange(from: old)
    }

    /// Writes the vault note shortly after the last change (sliders send many).
    private func scheduleNoteWrite() {
        notePending = true
        noteWrite?.cancel()
        noteWrite = Task {
            try? await delay.wait(rules.vault.settingsWriteDelaySeconds)
            guard !Task.isCancelled else { return }
            await writeNote()
        }
    }

    /// A change not written yet goes to the note before the note is read, so a sync does not undo it.
    private func flushNote() async {
        guard notePending else { return }
        noteWrite?.cancel()
        await writeNote()
    }

    /// A failed write stays pending and is tried again before the next read.
    private func writeNote() async {
        guard let json = try? JSONEncoder.store.encode(SyncedSettings(settings)) else { return }
        do {
            try await note.write(json)
            notePending = false
        } catch {
            notePending = true
        }
    }
}
