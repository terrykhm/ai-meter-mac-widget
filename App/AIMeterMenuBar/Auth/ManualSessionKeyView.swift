import SwiftUI
import AIMeterKit

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

    private var canSubmit: Bool {
        sessionKey.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter session key manually")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(UsageColors.textPrimary)

            Text("In Safari or Chrome, sign into claude.ai, then open Web Inspector → Storage/Application → Cookies → https://claude.ai. Copy the value of the sessionKey cookie (and lastActiveOrg, if present) and paste them below.")
                .font(.caption)
                .foregroundStyle(UsageColors.textSecondary())
                .fixedSize(horizontal: false, vertical: true)

            field(label: "sessionKey", placeholder: "sk-ant-sid01-...", text: $sessionKey)
            field(label: "lastActiveOrg (organization id)", placeholder: "org uuid", text: $organizationId)

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Back", action: onBack)
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(UsageColors.textSecondary())
                Spacer()
                Button(action: submit) {
                    Text("Sign in")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(UsageColors.accent))
                        .shadow(color: UsageColors.signInButtonShadow, radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.5)
            }
        }
        .padding(24)
        .frame(width: 480, alignment: .top)
        .frame(maxHeight: .infinity)
    }

    private func field(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(UsageColors.textPrimary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .padding(10)
                .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(UsageColors.textPrimary.opacity(0.12))
                )
        }
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
