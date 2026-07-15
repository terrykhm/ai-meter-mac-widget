import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService` for the "Launch at Login" toggle.
enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Best-effort: registration can fail if the app isn't in
            // /Applications yet (e.g. running from Xcode's DerivedData).
            // Nothing destructive to roll back — the toggle just won't
            // stick until the app is installed properly.
        }
    }
}
