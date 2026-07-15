import WebKit

/// Warms the WKWebView disk cache for claude.ai's login page before the
/// user actually clicks "Sign in". `LoginWebView`'s `WKWebView` uses the
/// same persistent `WKWebsiteDataStore.default()`, so whatever this
/// fetches here — the page shell, JS bundle, fonts — is already on disk
/// (much faster) by the time the real sign-in window loads the same URL.
///
/// This webview is never added to any window; a detached `WKWebView`
/// still performs its network load and populates the shared cache, it
/// just never renders anywhere, which is all prefetching needs.
@MainActor
final class LoginPagePrefetcher {
    private var webView: WKWebView?

    /// Idempotent — safe to call every time Settings opens while signed
    /// out. Does nothing once a prefetch (or the real sign-in) is
    /// already underway this app run.
    func prefetch() {
        guard webView == nil else { return }
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
        self.webView = webView
    }

    /// Called once the real sign-in window takes over — the cache
    /// benefit is already realized, no reason to keep this hidden
    /// webview around.
    func stop() {
        webView = nil
    }
}
