import SwiftUI
import WebKit

/// Wraps a `WKWebView` loading claude.ai's normal login page. Watches the
/// web view's cookie store for the `sessionKey` cookie to appear (i.e.
/// login succeeded) and reports it back via `onSessionCookie`.
///
/// Note: an embedded `WKWebView` can occasionally be Cloudflare-challenged
/// differently than real Safari. `ManualSessionKeyView` is the fallback
/// path for when that happens.
struct LoginWebView: NSViewRepresentable {
    var onSessionCookie: (_ sessionKey: String, _ lastActiveOrg: String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionCookie: onSessionCookie)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        configuration.websiteDataStore.httpCookieStore.add(context.coordinator)
        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
        private let onSessionCookie: (_ sessionKey: String, _ lastActiveOrg: String?) -> Void
        private var didReport = false

        init(onSessionCookie: @escaping (_ sessionKey: String, _ lastActiveOrg: String?) -> Void) {
            self.onSessionCookie = onSessionCookie
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            guard !didReport else { return }
            cookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.didReport else { return }
                guard let sessionKey = cookies.first(where: {
                    $0.name == "sessionKey" && $0.domain.contains("claude.ai")
                })?.value else {
                    return
                }
                let lastActiveOrg = cookies.first(where: {
                    $0.name == "lastActiveOrg" && $0.domain.contains("claude.ai")
                })?.value

                self.didReport = true
                DispatchQueue.main.async {
                    self.onSessionCookie(sessionKey, lastActiveOrg)
                }
            }
        }
    }
}
