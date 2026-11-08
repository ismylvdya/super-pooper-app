import Foundation

/// The user's own lists: third-level headings in the Lists section of the tasks file.
extension TaskFileStore: CustomListKeeping {
    func addList(_ title: String) async throws {
        try await changeDocument { $0.addList(title) }
    }

    func removeList(_ title: String) async throws {
        try await changeDocument { $0.removeList(title) }
    }

    private func changeDocument(_ change: @escaping (inout TaskDocument) -> Void) async throws {
        try await location.withRoot { root in
            var snapshot = try await read(root: root)
            change(&snapshot.document)
            try write(snapshot.document, root: root)
        }
    }
}
