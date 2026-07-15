import Foundation

/// Bridges the widget extension's "I was just asked to render a
/// timeline, please get me fresh data" signal into the app, via a Darwin
/// notification — the one IPC mechanism that works between an app and
/// its extension without an App Group (which this project can't use,
/// being signed with a free "Personal Team" — see
/// `SharedStorageLocation`). Darwin notifications carry no payload, just
/// a name; the app treats receiving one purely as a hint to refresh,
/// nothing more.
///
/// The sandboxed widget extension needs an explicit
/// `com.apple.security.temporary-exception.mach-lookup.global-name`
/// entitlement for `com.apple.system.notification_center` to actually
/// post one that reaches another process — without it, `postRefreshRequest`
/// still "succeeds" (no error, no crash) but the notification is silently
/// dropped and the app never sees it. Confirmed with temporary logging on
/// both sides during development: zero notifications arrived without the
/// entitlement, every one arrived with it. See
/// `AIMeterWidgetExtension.entitlements`.
public enum WidgetRefreshRequestObserver {
    static let notificationName = "com.terrykhm.aimeter.widgetRequestedRefresh" as CFString

    /// Called by the widget extension's `TimelineProvider` whenever the
    /// system asks it to render (i.e. the widget is actually visible).
    public static func postRefreshRequest() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName),
            nil, nil, true
        )
    }

    /// Called once by the app to start reacting to future requests.
    /// Keep the returned token alive for as long as you want to keep
    /// observing — deallocating it removes the observer.
    public static func observe(_ onRequest: @escaping () -> Void) -> AnyObject {
        Observer(onRequest: onRequest)
    }

    private final class Observer {
        private let onRequest: () -> Void

        init(onRequest: @escaping () -> Void) {
            self.onRequest = onRequest
            let observer = Unmanaged.passUnretained(self).toOpaque()
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                observer,
                { _, observer, _, _, _ in
                    guard let observer else { return }
                    Unmanaged<Observer>.fromOpaque(observer).takeUnretainedValue().onRequest()
                },
                notificationName,
                nil,
                .deliverImmediately
            )
        }

        deinit {
            CFNotificationCenterRemoveObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                Unmanaged.passUnretained(self).toOpaque(),
                CFNotificationName(notificationName),
                nil
            )
        }
    }
}
