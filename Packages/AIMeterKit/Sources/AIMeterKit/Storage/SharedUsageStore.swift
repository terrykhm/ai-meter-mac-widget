import Foundation

/// Reads/writes the latest usage snapshot to a fixed location under the
/// user's home directory (see `SharedStorageLocation`) so the widget
/// extension can display it without ever making network calls or touching
/// Keychain itself.
public struct SharedUsageStore {
    /// Defaults to the real shared location; overridable so tests don't
    /// read/write the actual app's shared file on the machine running them.
    private let directoryURL: URL

    public init(directoryURL: URL = SharedStorageLocation.directoryURL) {
        self.directoryURL = directoryURL
    }

    private var snapshotURL: URL {
        directoryURL.appendingPathComponent(SharedStorageLocation.snapshotFilename)
    }

    private var errorStateURL: URL {
        directoryURL.appendingPathComponent(SharedStorageLocation.errorStateFilename)
    }

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    public func save(_ snapshot: UsageSnapshot) throws {
        ensureDirectoryExists()
        let data = try Self.makeEncoder().encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
    }

    public func loadLatest() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? Self.makeDecoder().decode(UsageSnapshot.self, from: data)
    }

    public func clearSnapshot() {
        try? FileManager.default.removeItem(at: snapshotURL)
    }

    public func saveError(_ state: FetchErrorState) {
        ensureDirectoryExists()
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: errorStateURL, options: .atomic)
    }

    public func loadError() -> FetchErrorState {
        guard let data = try? Data(contentsOf: errorStateURL) else { return .none }
        return (try? JSONDecoder().decode(FetchErrorState.self, from: data)) ?? .none
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
