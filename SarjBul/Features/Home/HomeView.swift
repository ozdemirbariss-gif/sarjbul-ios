import CoreLocation
import SarjBulCore
import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var locationManager = LocationManager()
    @State private var manualLatitude = 38.3939
    @State private var manualLongitude = 27.1891

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    statusChip
                    quickActions
                    locationSection
                    drivingProfile
                    routeAction
                }
                .padding(22)
            }
            .background(SBColor.background.ignoresSafeArea())
            .sbInlineNavigationTitle()
            .onReceive(locationManager.$lastLocation.compactMap { $0 }) { location in
                appState.updateLocation(latitude: location.latitude, longitude: location.longitude, source: .device)
            }
            .alert("İşlem tamamlanamadı", isPresented: Binding(
                get: { appState.message != nil },
                set: { if !$0 { appState.dismissMessage() } }
            )) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(appState.message ?? "")
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ELEKTRİKLİ YOLCULUK")
                .font(.caption.weight(.heavy))
                .foregroundStyle(SBColor.accent)
            Text("Şarj noktanı bul.")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(SBColor.ink)
                .minimumScaleFactor(0.72)
            Text("Konumunu ve sürüş profilini seç, en uygun durağı hemen çıkaralım.")
                .font(.headline)
                .foregroundStyle(SBColor.muted)
        }
        .padding(.top, 10)
    }

    private var statusChip: some View {
        Text(appState.stationLoadChipText)
            .font(.caption.weight(.bold))
            .foregroundStyle(SBColor.navy)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.72))
            .clipShape(Capsule())
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.stationLoadChipText)
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            preferenceButton(.nearest, icon: "location.north.line")
            preferenceButton(.fastest, icon: "bolt.fill")
            preferenceButton(.economical, icon: "creditcard")
            Button {
                Haptic.tap()
                appState.tab = .lounge
            } label: {
                Label("Salon", systemImage: "gamecontroller")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(QuickActionStyle(active: appState.tab == .lounge))
        }
    }

    private func preferenceButton(_ preference: RoutePreference, icon: String) -> some View {
        Button {
            Haptic.tap()
            appState.filters.preference = preference
        } label: {
            Label(preference.title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(QuickActionStyle(active: appState.filters.preference == preference))
    }

    private var locationSection: some View {
        SBPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "scope")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(SBColor.navy)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nereden başlıyorsun?")
                            .font(.title3.weight(.bold))
                        Text(locationLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SBColor.muted)
                    }
                    Spacer()
                }

                SBPrimaryButton(title: "Konumumu kullan", systemImage: "location.fill") {
                    Haptic.tap()
                    locationManager.requestLocation()
                }

                if appState.userLocation?.source != .device {
                    VStack(spacing: 10) {
                        HStack {
                            TextField("Enlem", value: $manualLatitude, format: .number.precision(.fractionLength(4)))
                                .sbDecimalKeyboard()
                            TextField("Boylam", value: $manualLongitude, format: .number.precision(.fractionLength(4)))
                                .sbDecimalKeyboard()
                        }
                        .textFieldStyle(.roundedBorder)

                        Button("Manuel konumu kullan") {
                            Haptic.tap()
                            appState.updateLocation(latitude: manualLatitude, longitude: manualLongitude, source: .manual)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private var locationLabel: String {
        guard let location = appState.userLocation else { return "Konum seçilmedi" }
        return String(format: "%.4f, %.4f", location.latitude, location.longitude)
    }

    private var drivingProfile: some View {
        SBPanel {
            VStack(alignment: .leading, spacing: 18) {
                Text("Sürüş Profili")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(SBColor.accent)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Şarj %")
                            .font(.headline.weight(.bold))
                        Spacer()
                        Text("%\(appState.profile.chargePercent)")
                            .font(.title2.weight(.heavy))
                    }
                    Slider(
                        value: Binding(
                            get: { Double(appState.profile.chargePercent) },
                            set: { appState.profile.chargePercent = Int($0.rounded()) }
                        ),
                        in: 1...100,
                        step: 1
                    )
                    .tint(SBColor.accent)
                }

                HStack(spacing: 12) {
                    MetricInput(
                        title: "Batarya kapasitesi",
                        unit: "kWh",
                        value: Binding(
                            get: { appState.profile.batteryKWh },
                            set: { appState.profile.batteryKWh = $0 }
                        ),
                        range: 1...250,
                        step: 1
                    )
                    MetricInput(
                        title: "Ortalama tüketim",
                        unit: "kWh",
                        value: Binding(
                            get: { appState.profile.consumptionKWhPer100Km },
                            set: { appState.profile.consumptionKWhPer100Km = $0 }
                        ),
                        range: 5...40,
                        step: 0.1
                    )
                }

                Text("\(Int(appState.profile.safeRangeKm.rounded())) km güvenli menzille yola hazırsın")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SBColor.ink)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: appState.profile.safeRangeKm)
            }
        }
    }

    private var routeAction: some View {
        SBPrimaryButton(title: appState.isSearching ? "Hesaplanıyor..." : "Şarj Bul", systemImage: "arrow.right") {
            Haptic.tap()
            Task {
                await appState.findStations()
                if !appState.routeCandidates.isEmpty {
                    Haptic.success()
                }
            }
        }
        .disabled(!appState.canSearch)
        .opacity(appState.canSearch ? 1 : 0.55)
    }
}

private struct QuickActionStyle: ButtonStyle {
    var active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(active ? SBColor.ink : SBColor.muted)
            .frame(height: 68)
            .background(active ? SBColor.accent.opacity(0.95) : .white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
