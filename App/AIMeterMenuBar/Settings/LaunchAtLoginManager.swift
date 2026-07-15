import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService` for launch-at-login registration.
/// Always enabled at startup (see `AppState.init`) — there's no user
/// toggle for this.
enum LaunchAtLoginManager {
    static func enable() {
        guard SMAppService.mainApp.status != .enabled else { return }
        do {
            try SMAppService.mainApp.register()
        } catch {
            // Best-effort: registration can fail if the app isn't in
            // /Applications yet (e.g. running from Xcode's DerivedData).
            // Nothing destructive to roll back — it just won't stick
            // until the app is installed properly.
        }
    }
}
