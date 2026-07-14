import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Where the app and widget extension exchange the usage snapshot.
///
/// This intentionally does NOT use an App Group container:
/// `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`
/// requires the App Groups capability, which Apple blocks on free
/// Personal Team accounts. The main app is unsandboxed, so it can read
/// this path directly. The widget extension IS sandboxed (macOS silently
/// refuses to register an unsandboxed WidgetKit extension at all) and
/// reaches this same path via a
/// `com.apple.security.temporary-exception.files.home-relative-path.read-write`
/// entitlement instead.
public enum SharedStorageLocation {
    static let directoryName = "ClaudeUsage"
    static let snapshotFilename = "usage-snapshot.json"
    static let errorStateFilename = "usage-error-state.json"

    /// `FileManager.homeDirectoryForCurrentUser` / `NSHomeDirectory()` are
    /// virtualized under App Sandbox: a sandboxed process gets back its
    /// own container path (e.g.
    /// `~/Library/Containers/<bundle-id>/Data`) instead of the real home
    /// directory, even with a home-relative temporary-exception
    /// entitlement granting access to the real path. `getpwuid` is a raw
    /// POSIX call that isn't subject to that redirection, so it's the
    /// only reliable way to get the actual home directory from inside the
    /// sandboxed widget extension. Without this, the widget silently
    /// looks for the snapshot inside its own (empty) container and always
    /// finds nothing.
    private static var realHomeDirectory: URL {
        if let passwd = getpwuid(getuid()) {
            let path = String(cString: passwd.pointee.pw_dir)
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    public static var directoryURL: URL {
        realHomeDirectory
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }
}
