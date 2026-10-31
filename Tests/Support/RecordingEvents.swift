import Foundation
@testable import SuperPooperApp

/// The app state's events, in the order they were sent.
@MainActor
final class RecordingEvents: AppEventSink {
    private(set) var sent: [AppEvent] = []

    func send(_ event: AppEvent) { sent.append(event) }
}
