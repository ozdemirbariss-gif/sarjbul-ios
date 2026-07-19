import SwiftUI

enum LegalDocument: String, Identifiable {
    case privacy
    case terms
    case support

    var id: String { rawValue }
}

struct LegalView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let document: LegalDocument

    var body: some View {
        NavigationStack {
            ZStack {
                SBScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Image(systemName: icon)
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(SBColor.accent)
                            .frame(width: 72, height: 72)
                            .background(SBColor.electricBlue)
                            .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))

                        Text(title)
                            .font(SBFont.display(size: 36, weight: .heavy))
                            .foregroundStyle(SBColor.ink)

                        Text(bodyText)
                            .font(.body)
                            .foregroundStyle(SBColor.textSoft)
                            .lineSpacing(6)
                            .textSelection(.enabled)

                        if let webURL {
                            linkButton(title: appState.t("legal.open_web"), icon: "safari") {
                                openURL(webURL)
                            }
                        }

                        if document == .support, let emailURL {
                            linkButton(title: appState.t("legal.email"), icon: "envelope") {
                                openURL(emailURL)
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 680, alignment: .leading)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appState.t("status.ok")) { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private var title: String {
        switch document {
        case .privacy: appState.t("legal.privacy_title")
        case .terms: appState.t("legal.terms_title")
        case .support: appState.t("legal.support_title")
        }
    }

    private var bodyText: String {
        switch document {
        case .privacy: appState.t("legal.privacy_body")
        case .terms: appState.t("legal.terms_body")
        case .support: appState.t("legal.support_body")
        }
    }

    private var icon: String {
        switch document {
        case .privacy: "hand.raised.fill"
        case .terms: "doc.text.fill"
        case .support: "questionmark.bubble.fill"
        }
    }

    private var webURL: URL? {
        switch document {
        case .privacy: appState.externalLinks.privacyPolicyURL
        case .terms: appState.externalLinks.termsOfUseURL
        case .support: appState.externalLinks.supportURL
        }
    }

    private var emailURL: URL? {
        guard !appState.externalLinks.supportEmail.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = appState.externalLinks.supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "SarjBul Support")]
        return components.url
    }

    private func linkButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(SBColor.electricBlue)
                .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
        }
        .buttonStyle(SBPremiumButtonStyle())
    }
}
