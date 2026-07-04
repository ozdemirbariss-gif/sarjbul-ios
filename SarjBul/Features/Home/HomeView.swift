import CoreLocation
import SarjBulCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var locationManager = LocationManager()
    @State private var manualLatitude = 38.3939
    @State private var manualLongitude = 27.1891

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
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
            .alert("Bilgi", isPresented: Binding(
                get: { appState.errorMessage != nil },
                set: { if !$0 { appState.errorMessage = nil } }
            )) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(appState.errorMessage ?? "")
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

    private var quickActions: some View {
        HStack(spacing: 10) {
            preferenceButton(.nearest, icon: "location.north.line")
            preferenceButton(.fastest, icon: "bolt.fill")
            preferenceButton(.economical, icon: "creditcard")
            Button {
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
                        value: $appState.profile.batteryKWh,
                        range: 1...250,
                        step: 1
                    )
                    MetricInput(
                        title: "Ortalama tüketim",
                        unit: "kWh",
                        value: $appState.profile.consumptionKWhPer100Km,
                        range: 5...40,
                        step: 0.1
                    )
                }

                Text("\(Int(appState.profile.safeRangeKm.rounded())) km güvenli menzille yola hazırsın")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SBColor.ink)
            }
        }
    }

    private var routeAction: some View {
        SBPrimaryButton(title: "Şarj Bul", systemImage: "arrow.right") {
            appState.findStations()
        }
        .disabled(appState.stations.isEmpty)
        .opacity(appState.stations.isEmpty ? 0.55 : 1)
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
    }
}
