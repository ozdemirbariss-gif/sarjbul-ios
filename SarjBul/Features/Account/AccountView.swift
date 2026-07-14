import SwiftUI

struct AccountView: View {
    @Environment(AppState.self) private var appState
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ZStack {
                SBScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        HStack {
                            Spacer()
                            SBLanguageSwitch(selectedLanguage: Binding(
                                get: { appState.language.displayCode },
                                set: { appState.setLanguage(code: $0) }
                            ))
                        }

                        heroPanel
                        guestPanel

                        if appState.isAuthenticated {
                            signedInPanel
                        } else {
                            authPanel
                        }
                    }
                    .padding(22)
                }
            }
        }
    }

    private var heroPanel: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                .fill(SBColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                        .stroke(SBColor.line, lineWidth: 1)
                )
                .sbSoftShadow()

            VStack(alignment: .leading, spacing: 56) {
                SBBrandMark()

                VStack(alignment: .leading, spacing: -10) {
                    Text(appState.t("auth.hero_line1"))
                        .font(SBFont.display(size: 72, weight: .heavy))
                        .foregroundStyle(SBColor.muted)
                    Text(appState.t("auth.hero_line2"))
                        .font(SBFont.display(size: 72, weight: .heavy))
                        .foregroundStyle(SBColor.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(SBColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
                }
                .minimumScaleFactor(0.72)

                HStack {
                    Spacer()
                    Capsule()
                        .fill(SBColor.accent)
                        .frame(width: 210, height: 18)
                        .offset(x: 76)
                }
            }
            .padding(28)
        }
        .frame(minHeight: 360)
    }

    private var guestPanel: some View {
        SBSecondaryPanel {
            VStack(alignment: .leading, spacing: 22) {
                Text(appState.t("auth.guest_primary_title"))
                    .font(SBFont.display(size: 30, weight: .heavy))
                    .foregroundStyle(SBColor.ink)
                Text(appState.t("auth.guest_primary_hint"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SBColor.muted)

                SBPrimaryButton(title: appState.t("auth.guest_primary_action"), systemImage: nil) {
                    Haptic.tap()
                    appState.tab = .home
                }
            }
        }
    }

    private var signedInPanel: some View {
        SBPanel {
            VStack(alignment: .leading, spacing: 16) {
                Label(appState.authSession?.email ?? appState.t("auth.verified_driver"), systemImage: "person.crop.circle.badge.checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SBColor.ink)

                Text(appState.t("auth.signed_in_hint"))
                    .font(.subheadline)
                    .foregroundStyle(SBColor.muted)

                Button(role: .destructive) {
                    Haptic.tap()
                    appState.signOut()
                } label: {
                    Label(appState.t("auth.logout"), systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var authPanel: some View {
        SBSecondaryPanel {
            VStack(alignment: .leading, spacing: 18) {
                Rectangle()
                    .fill(SBColor.line)
                    .frame(height: 3)
                    .clipShape(Capsule())

                Text(appState.t("auth.card_title"))
                    .font(SBFont.display(size: 30, weight: .heavy))
                    .foregroundStyle(SBColor.ink)
                Text(appState.t("auth.card_hint"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SBColor.muted)

                if mode == .reset {
                    Text(appState.t("auth.reset_hint"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SBColor.muted)
                } else {
                    Picker(appState.t("auth.mode_label"), selection: $mode) {
                        ForEach([AuthMode.signIn, AuthMode.signUp]) { mode in
                            Text(mode.title(appState)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in
                        password = ""
                    }
                }

                TextField(appState.t("auth.email"), text: $email)
                    .sbEmailInput()
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(SBColor.glass)
                    .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous)
                            .stroke(SBColor.line, lineWidth: 1)
                    )

                if mode != .reset {
                    SecureField(appState.t("auth.password"), text: $password)
                        .sbPasswordInput(isNewPassword: mode == .signUp)
                        .onSubmit { Task { await submit() } }
                        .textFieldStyle(.plain)
                        .padding(16)
                        .background(SBColor.glass)
                        .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous)
                                .stroke(SBColor.line, lineWidth: 1)
                        )
                }

                SBPrimaryButton(title: isWorking ? mode.loadingTitle(appState) : mode.actionTitle(appState), systemImage: mode.icon) {
                    Task { await submit() }
                }
                .disabled(isWorking || !formIsValid)
                .opacity(formIsValid ? 1 : 0.55)

                if mode == .reset {
                    Button {
                        Haptic.tap()
                        mode = .signIn
                    } label: {
                        Text(appState.t("auth.back_to_login"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(SBColor.electricBlue)
                    }
                } else {
                    Button {
                        Haptic.tap()
                        mode = .reset
                    } label: {
                        Text(appState.t("auth.forgot_password"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(SBColor.electricBlue)
                    }
                }

                if !appState.isFirebaseConfigured {
                    Text(appState.t("auth.firebase_config_required"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SBColor.muted)
                }
            }
        }
    }

    private var formIsValid: Bool {
        let hasEmail = email.contains("@") && email.contains(".")
        if mode == .reset { return hasEmail }
        return hasEmail && password.count >= 6
    }

    private func submit() async {
        guard formIsValid, !isWorking else { return }
        Haptic.tap()
        isWorking = true
        defer { isWorking = false }

        switch mode {
        case .signIn:
            await appState.signIn(email: email, password: password)
        case .signUp:
            await appState.signUp(email: email, password: password)
        case .reset:
            await appState.resetPassword(email: email)
        }
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn
    case signUp
    case reset

    var id: String { rawValue }

    @MainActor
    func title(_ appState: AppState) -> String {
        switch self {
        case .signIn: appState.t("auth.login")
        case .signUp: appState.t("auth.register")
        case .reset: appState.t("auth.reset")
        }
    }

    @MainActor
    func actionTitle(_ appState: AppState) -> String {
        switch self {
        case .signIn: appState.t("auth.login_action")
        case .signUp: appState.t("auth.register_action")
        case .reset: appState.t("auth.reset_action")
        }
    }

    @MainActor
    func loadingTitle(_ appState: AppState) -> String {
        switch self {
        case .signIn: appState.t("auth.login_loading")
        case .signUp: appState.t("auth.register_loading")
        case .reset: appState.t("auth.reset_loading")
        }
    }

    var icon: String {
        switch self {
        case .signIn: "person.fill.checkmark"
        case .signUp: "person.badge.plus"
        case .reset: "envelope"
        }
    }
}
