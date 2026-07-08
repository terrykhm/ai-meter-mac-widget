import Foundation

/// Reads/writes the latest usage snapshot to the App Group container so the
/// widget extension can display it without ever making network calls or
/// touching Keychain itself.
public struct SharedUsageStore {
    public init() {}

    private var snapshotURL: URL? {
        AppGroupConstants.containerURL?.appendingPathComponent(AppGroupConstants.snapshotFilename)
    }

    private var errorStateURL: URL? {
        AppGroupConstants.containerURL?.appendingPathComponent(AppGroupConstants.errorStateFilename)
    }

    public func save(_ snapshot: UsageSnapshot) throws {
        guard let url = snapshotURL else { throw SharedUsageStoreError.appGroupContainerUnavailable }
        let data = try Self.makeEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    public func loadLatest() -> UsageSnapshot? {
        guard let url = snapshotURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.makeDecoder().decode(UsageSnapshot.self, from: data)
    }

    public func clearSnapshot() {
        guard let url = snapshotURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    public func saveError(_ state: FetchErrorState) {
        guard let url = errorStateURL else { return }
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public func loadError() -> FetchErrorState {
        guard let url = errorStateURL, let data = try? Data(contentsOf: url) else { return .none }
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

public enum SharedUsageStoreError: Error {
    case appGroupContainerUnavailable
}
