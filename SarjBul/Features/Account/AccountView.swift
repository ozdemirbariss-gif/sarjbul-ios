import SarjBulCore
import SwiftUI

struct AccountView: View {
    @Environment(AppState.self) private var appState
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var isDeletingAccount = false
    @State private var deleteConfirmationPresented = false
    @State private var legalDocument: LegalDocument?
    @State private var passwordVisible = false
    @State private var inlineError: String?
    @FocusState private var focusedField: AuthField?
    @ScaledMetric(relativeTo: .largeTitle) private var heroLineOneSize = 82
    @ScaledMetric(relativeTo: .largeTitle) private var heroLineTwoSize = 86

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
                            stationLibraryPanel
                        } else {
                            authPanel
                        }

                        legalFooter
                    }
                    .padding(22)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .sensoryFeedback(.selection, trigger: appState.language)
            }
            .sheet(item: $legalDocument) { document in
                LegalView(document: document)
                    .environment(appState)
            }
            .confirmationDialog(
                appState.t("auth.delete_title"),
                isPresented: $deleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(appState.t("auth.delete_confirm"), role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button(appState.t("auth.delete_cancel"), role: .cancel) {}
            } message: {
                Text(appState.t("auth.delete_message"))
            }
        }
    }

    private var heroPanel: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                .fill(LinearGradient.sbSoftPanel)
                .overlay(
                    RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                        .stroke(SBColor.line, lineWidth: 1)
                )
                .sbSoftShadow()

            VStack(alignment: .leading, spacing: 34) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(LinearGradient.sbPrimary)
                        .frame(width: 34, height: 34)
                        .overlay(alignment: .trailing) {
                            Circle()
                                .fill(SBColor.accent)
                                .frame(width: 38, height: 38)
                                .opacity(0.2)
                                .offset(x: 22)
                        }
                    Circle()
                        .fill(SBColor.accent)
                        .frame(width: 12, height: 12)
                        .padding(.leading, 8)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(SBColor.glassStrong)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(SBColor.line, lineWidth: 1)
                )
                .sbSoftShadow()

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.t("auth.hero_line1"))
                        .font(SBFont.display(size: min(heroLineOneSize, 112), weight: .heavy))
                        .foregroundStyle(SBColor.ink.opacity(0.46))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(appState.t("auth.hero_line2"))
                        .font(SBFont.display(size: min(heroLineTwoSize, 116), weight: .heavy))
                        .foregroundStyle(SBColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [SBColor.accent, SBColor.primaryDeep.opacity(0.78)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: SBColor.accent.opacity(0.26), radius: 24, x: 0, y: 14)
                }

                HStack {
                    Spacer()
                    Capsule()
                        .fill(LinearGradient.sbNeon)
                        .frame(width: 230, height: 14)
                        .offset(x: 88)
                }
            }
            .padding(30)
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

                SBPrimaryButton(
                    title: appState.t("auth.guest_primary_action"),
                    systemImage: nil,
                    accessibilityIdentifier: "guest-start-button"
                ) {
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

                Button(role: .destructive) {
                    Haptic.tap()
                    deleteConfirmationPresented = true
                } label: {
                    Label(
                        isDeletingAccount ? appState.t("auth.delete_loading") : appState.t("auth.delete_account"),
                        systemImage: "trash"
                    )
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isDeletingAccount)
            }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 14) {
            HStack(spacing: 22) {
                legalButton(appState.t("auth.privacy"), document: .privacy)
                legalButton(appState.t("auth.terms"), document: .terms)
                legalButton(appState.t("auth.support"), document: .support)
            }

            Text(appState.t("auth.version", ["version": appVersion]))
                .font(.caption.weight(.semibold))
                .foregroundStyle(SBColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var stationLibraryPanel: some View {
        let favorites = appState.favoriteStations
        let recent = appState.recentStations

        if !favorites.isEmpty || !recent.isEmpty {
            SBSecondaryPanel {
                VStack(alignment: .leading, spacing: 20) {
                    if !favorites.isEmpty {
                        stationSection(title: appState.t("library.favorites"), stations: favorites)
                    }
                    if !recent.isEmpty {
                        stationSection(title: appState.t("library.recent"), stations: recent)
                    }
                }
            }
        }
    }

    private func stationSection(title: String, stations: [SarjBulCore.Station]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(SBColor.ink)

            ForEach(Array(stations.prefix(4))) { station in
                Button {
                    Haptic.tap()
                    Task { await appState.openStation(withKey: station.statusKey) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(SBColor.accent)
                            .frame(width: 38, height: 38)
                            .background(SBColor.electricBlue)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(station.name)
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(SBColor.ink)
                                .lineLimit(1)
                            Text(station.operatorName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SBColor.muted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(SBColor.electricBlue)
                    }
                    .padding(12)
                    .sbPremiumGlass(radius: SBRadius.md, interactive: true)
                }
                .buttonStyle(SBPremiumButtonStyle())
                .accessibilityHint(appState.t("library.open_route"))
            }
        }
    }

    private func legalButton(_ title: String, document: LegalDocument) -> some View {
        Button(title) {
            Haptic.tap()
            legalDocument = document
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(SBColor.electricBlue)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        _ = await appState.deleteAccount()
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
                        inlineError = nil
                    }
                }

                authInputContainer(field: .email) {
                    Image(systemName: "envelope")
                        .foregroundStyle(SBColor.muted)
                    TextField(appState.t("auth.email_placeholder"), text: $email)
                        .sbEmailInput()
                        .focused($focusedField, equals: .email)
                        .submitLabel(mode == .reset ? .go : .next)
                        .onSubmit {
                            if mode == .reset {
                                Task { await submit() }
                            } else {
                                focusedField = .password
                            }
                        }
                        .accessibilityLabel(appState.t("auth.email"))
                }

                if mode != .reset {
                    authInputContainer(field: .password) {
                        Image(systemName: "lock")
                            .foregroundStyle(SBColor.muted)
                        Group {
                            if passwordVisible {
                                TextField(appState.t("auth.password_placeholder"), text: $password)
                            } else {
                                SecureField(appState.t("auth.password_placeholder"), text: $password)
                            }
                        }
                        .sbPasswordInput(isNewPassword: mode == .signUp)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await submit() } }
                        .accessibilityLabel(appState.t("auth.password"))

                        Button {
                            passwordVisible.toggle()
                        } label: {
                            Image(systemName: passwordVisible ? "eye.slash" : "eye")
                                .foregroundStyle(SBColor.muted)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(passwordVisible ? "Hide password" : "Show password")
                    }
                }

                if let inlineError {
                    Label(inlineError, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SBColor.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isStaticText)
                }

                SBPrimaryButton(
                    title: isWorking ? mode.loadingTitle(appState) : mode.actionTitle(appState),
                    systemImage: mode.icon,
                    accessibilityIdentifier: "auth-submit-button"
                ) {
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

    private func authInputContainer<Content: View>(
        field: AuthField,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10, content: content)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .background(SBColor.glass)
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous)
                    .stroke(focusedField == field ? SBColor.electricBlue : SBColor.line, lineWidth: 1)
            )
            .shadow(
                color: focusedField == field ? SBColor.electricBlue.opacity(0.14) : .clear,
                radius: 10
            )
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
        inlineError = appState.consumeErrorMessage()
        if inlineError == nil {
            focusedField = nil
        }
    }
}

private enum AuthField: Hashable {
    case email
    case password
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
