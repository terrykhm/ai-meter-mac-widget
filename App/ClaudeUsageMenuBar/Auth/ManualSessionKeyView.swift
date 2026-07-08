import SwiftUI
import ClaudeUsageKit

/// Fallback sign-in path: the user copies their `sessionKey` cookie value
/// from their own browser's dev tools and pastes it here. Exists because
/// the embedded `WKWebView` login can get Cloudflare-challenged
/// differently than a real browser would.
struct ManualSessionKeyView: View {
    var onSubmit: (ClaudeSessionCredentials) -> Void
    var onBack: () -> Void

    @State private var sessionKey: String = ""
    @State private var organizationId: String = ""
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Enter session key manually")
                .font(.headline)

            Text("In Safari or Chrome, sign into claude.ai, then open Web Inspector → Storage/Application → Cookies → https://claude.ai. Copy the value of the sessionKey cookie (and lastActiveOrg, if present) and paste them below.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("sessionKey").font(.caption.bold())
                TextField("sk-ant-sid01-...", text: $sessionKey)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("lastActiveOrg (organization id)").font(.caption.bold())
                TextField("org uuid", text: $organizationId)
                    .textFieldStyle(.roundedBorder)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Back", action: onBack)
                Spacer()
                Button("Sign in") {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(sessionKey.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
            }
        }
        .padding(20)
        .frame(width: 480, height: 620, alignment: .top)
    }

    private func submit() {
        let trimmedKey = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOrg = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedKey.count >= 10 else {
            validationMessage = "That doesn't look like a valid session key."
            return
        }
        onSubmit(ClaudeSessionCredentials(sessionKey: trimmedKey, organizationId: trimmedOrg))
    }
}
