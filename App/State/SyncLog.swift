import Foundation
import os

/// The sync log in Console (subsystem SuperPooper, category sync).
enum SyncLog {
    static let logger = Logger(subsystem: "SuperPooperApp", category: "sync")
}
