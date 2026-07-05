import SwiftUI

struct AccountView: View {
    @Environment(AppState.self) private var appState
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var language = "TR"

    var body: some View {
        NavigationStack {
            ZStack {
                SBScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        HStack {
                            Spacer()
                            SBLanguageSwitch(selectedLanguage: $language)
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
                    Text("Akımı")
                        .font(SBFont.display(size: 72, weight: .heavy))
                        .foregroundStyle(SBColor.muted)
                    Text("yakala.")
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
                Text("En yakın şarjı hemen bul")
                    .font(SBFont.display(size: 30, weight: .heavy))
                    .foregroundStyle(SBColor.ink)
                Text("Üyelik gerekmez. Konumunu seçip rotanı oluşturabilirsin.")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SBColor.muted)

                SBPrimaryButton(title: "Hemen başla", systemImage: nil) {
                    Haptic.tap()
                    appState.tab = .home
                }
            }
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
        SBSecondaryPanel {
            VStack(alignment: .leading, spacing: 18) {
                Rectangle()
                    .fill(SBColor.line)
                    .frame(height: 3)
                    .clipShape(Capsule())

                Text("Hesabınla devam et")
                    .font(SBFont.display(size: 30, weight: .heavy))
                    .foregroundStyle(SBColor.ink)
                Text("Favoriler ve bildirimler hesabına kaydedilir.")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SBColor.muted)

                if mode == .reset {
                    Text("Şifre sıfırlama bağlantısı e-postana gönderilir.")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SBColor.muted)
                } else {
                    Picker("Hesap işlemi", selection: $mode) {
                        ForEach([AuthMode.signIn, AuthMode.signUp]) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in
                        password = ""
                    }
                }

                TextField("E-posta", text: $email)
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
                    SecureField("Şifre", text: $password)
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

                SBPrimaryButton(title: isWorking ? "İşleniyor..." : mode.actionTitle, systemImage: mode.icon) {
                    Task { await submit() }
                }
                .disabled(isWorking || !formIsValid)
                .opacity(formIsValid ? 1 : 0.55)

                if mode == .reset {
                    Button {
                        Haptic.tap()
                        mode = .signIn
                    } label: {
                        Text("Girişe dön")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(SBColor.electricBlue)
                    }
                } else {
                    Button {
                        Haptic.tap()
                        mode = .reset
                    } label: {
                        Text("Şifremi unuttum")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(SBColor.electricBlue)
                    }
                }

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
