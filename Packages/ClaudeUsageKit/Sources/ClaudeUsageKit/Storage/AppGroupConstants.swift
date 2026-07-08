import Foundation

public enum AppGroupConstants {
    /// Must exactly match the App Group configured in both targets'
    /// `.entitlements` files and the placeholder substitution in
    /// `project.yml`. See README.md's setup checklist.
    public static let identifier = "group.REPLACE_ME_BUNDLE_PREFIX.claudeusage"

    static let snapshotFilename = "usage-snapshot.json"
    static let errorStateFilename = "usage-error-state.json"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
