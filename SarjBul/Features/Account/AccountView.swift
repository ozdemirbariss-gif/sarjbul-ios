import SwiftUI

struct AccountView: View {
    @Environment(AppState.self) private var appState
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Hesap")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(SBColor.ink)

                    if appState.isAuthenticated {
                        signedInPanel
                    } else {
                        authPanel
                    }
                }
                .padding(22)
            }
            .background(SBColor.background.ignoresSafeArea())
        }
    }

    private var signedInPanel: some View {
        SBPanel {
            VStack(alignment: .leading, spacing: 16) {
                Label(appState.authSession?.email ?? "Doğrulanmış sürücü", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SBColor.ink)

                Text("Favoriler ve durum bildirimleri bu hesapla senkronize edilir.")
                    .font(.subheadline)
                    .foregroundStyle(SBColor.muted)

                Button(role: .destructive) {
                    Haptic.tap()
                    appState.signOut()
                } label: {
                    Label("Çıkış yap", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var authPanel: some View {
        SBPanel {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Hesap işlemi", selection: $mode) {
                    ForEach(AuthMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                TextField("E-posta", text: $email)
                    .sbEmailInput()
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(.white.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if mode != .reset {
                    SecureField("Şifre", text: $password)
                        .sbPasswordInput(isNewPassword: mode == .signUp)
                        .onSubmit { Task { await submit() } }
                        .textFieldStyle(.plain)
                        .padding(16)
                        .background(.white.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                SBPrimaryButton(title: isWorking ? "İşleniyor..." : mode.actionTitle, systemImage: mode.icon) {
                    Task { await submit() }
                }
                .disabled(isWorking || !formIsValid)
                .opacity(formIsValid ? 1 : 0.55)

                Button {
                    Haptic.tap()
                    mode = .reset
                } label: {
                    Text("Şifremi unuttum")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SBColor.navy)
                }
                .opacity(mode == .reset ? 0 : 1)
                .disabled(mode == .reset)

                if !appState.isFirebaseConfigured {
                    Text("Firebase ayarları için AppConfig.plist eklenmeli.")
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

    var title: String {
        switch self {
        case .signIn: "Giriş"
        case .signUp: "Kayıt"
        case .reset: "Sıfırla"
        }
    }

    var actionTitle: String {
        switch self {
        case .signIn: "Giriş yap"
        case .signUp: "Kayıt ol"
        case .reset: "Sıfırlama bağlantısı gönder"
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
