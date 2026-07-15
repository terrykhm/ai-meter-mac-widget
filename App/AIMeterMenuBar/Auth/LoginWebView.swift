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
    /// Tracks whether the page is still loading, so the window can show a
    /// spinner over it instead of blank space — a fresh `WKWebView` (or
    /// one with a just-cleared cache) can take several seconds to
    /// download and render claude.ai's JS bundle with no visual feedback
    /// otherwise.
    @Binding var isLoading: Bool
    var onSessionCookie: (_ sessionKey: String, _ lastActiveOrg: String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionCookie: onSessionCookie, isLoading: $isLoading)
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
        private let isLoading: Binding<Bool>
        private var didReport = false

        init(onSessionCookie: @escaping (_ sessionKey: String, _ lastActiveOrg: String?) -> Void, isLoading: Binding<Bool>) {
            self.onSessionCookie = onSessionCookie
            self.isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading.wrappedValue = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
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
