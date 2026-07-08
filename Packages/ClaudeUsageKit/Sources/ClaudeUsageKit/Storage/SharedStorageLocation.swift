import Foundation

/// Where the app and widget extension exchange the usage snapshot.
///
/// This intentionally does NOT use an App Group container:
/// `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`
/// requires the App Groups capability, which Apple blocks on free
/// Personal Team accounts. Since neither target declares an App Sandbox
/// entitlement, both processes run as the current user with normal file
/// access, so a plain fixed path under the user's home directory works
/// without any special capability.
public enum SharedStorageLocation {
    static let directoryName = "ClaudeUsage"
    static let snapshotFilename = "usage-snapshot.json"
    static let errorStateFilename = "usage-error-state.json"

    public static var directoryURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    @discardableResult
    static func ensureDirectoryExists() -> URL {
        let url = directoryURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
