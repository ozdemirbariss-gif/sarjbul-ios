import CoreLocation
import SarjBulCore
import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var locationManager = LocationManager()
    @State private var manualLatitude = 38.3939
    @State private var manualLongitude = 27.1891
    @State private var selectedPreset: ManualLocationPreset?
    @State private var didRequestDeviceLocation = false
    @State private var locationRequestTimedOut = false
    @State private var settingsExpanded = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                SBScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        topControls
                        drivingProfile
                        filtersAndSettings
                        routeAction
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 28)
                }
                .scrollIndicators(.hidden)
                .sensoryFeedback(.selection, trigger: appState.filters.preference)

                SBBackButton(accessibilityLabel: appState.t("nav.back")) {
                    appState.tab = .account
                }
                .padding(.leading, 18)
                .padding(.top, 6)
            }
            .sbInlineNavigationTitle()
            .onReceive(locationManager.$lastLocation.compactMap { $0 }) { location in
                appState.updateLocation(latitude: location.latitude, longitude: location.longitude, source: .device)
            }
            .onAppear {
                guard !didRequestDeviceLocation, appState.userLocation == nil else { return }
                requestDeviceLocation()
            }
        }
    }

    private var topControls: some View {
        HStack(spacing: 16) {
            preferenceButton(.nearest, icon: "location.north.line")
            preferenceButton(.fastest, icon: "bolt.fill")
            preferenceButton(.economical, icon: "fuelpump")
        }
        .padding(.leading, 34)
        .padding(.top, 10)
    }

    private func preferenceButton(_ preference: RoutePreference, icon: String) -> some View {
        Button {
            Haptic.tap()
            appState.filters.preference = preference
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.headline.weight(.heavy))
                    .symbolEffect(.bounce, value: appState.filters.preference == preference)
                Text(preferenceTitle(preference))
                    .font(.caption.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(QuickActionStyle(active: appState.filters.preference == preference))
    }

    @ViewBuilder
    private var locationSection: some View {
        if appState.userLocation?.source != .device {
            SBPanel {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "scope")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(SBColor.electricBlue)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.t("home.search_title"))
                                .font(.title3.weight(.bold))
                            Text(locationLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SBColor.muted)
                        }
                        Spacer()
                    }

                    SBPrimaryButton(title: appState.t("home.use_location"), systemImage: "location.fill") {
                        Haptic.tap()
                        requestDeviceLocation()
                    }

                    if manualLocationEntryVisible {
                        manualLocationForm
                    } else {
                        Text(locationWaitingText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(SBColor.muted)
                    }
                }
            }
        }
    }

    private var locationLabel: String {
        guard let location = appState.userLocation else { return appState.t("home.location_selected") }
        return String(format: "%.4f, %.4f", location.latitude, location.longitude)
    }

    private var drivingProfile: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.t("catalog.kicker"))
                .font(.headline.weight(.heavy))
                .foregroundStyle(SBColor.primaryDeep)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            SBPanel {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(appState.t("catalog.charge_percent"))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(SBColor.muted)
                        Spacer()
                        Text("\(appState.profile.chargePercent)")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(SBColor.muted)
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

                ChargeVisual(
                    percent: appState.profile.chargePercent,
                    statusText: chargeStatusText,
                    chargeLabel: appState.t("charge.label"),
                    selectedLevelText: appState.t("charge.selected_level")
                )

                Divider()
                    .overlay(SBColor.line)

                HStack(spacing: 12) {
                    MetricInput(
                        title: appState.t("catalog.capacity"),
                        unit: "kWh",
                        value: Binding(
                            get: { appState.profile.batteryKWh },
                            set: { appState.profile.batteryKWh = $0 }
                        ),
                        range: 1...250,
                        step: 1
                    )
                    MetricInput(
                        title: appState.t("catalog.consumption"),
                        unit: "kWh",
                        value: Binding(
                            get: { appState.profile.consumptionKWhPer100Km },
                            set: { appState.profile.consumptionKWhPer100Km = $0 }
                        ),
                        range: 5...40,
                        step: 0.1
                    )
                }
            }
        }
    }

    private var filtersAndSettings: some View {
        DisclosureGroup(isExpanded: $settingsExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                locationSection
                Toggle(appState.t("filters.range"), isOn: Binding(
                    get: { appState.filters.rangeFilterEnabled },
                    set: { appState.filters.rangeFilterEnabled = $0 }
                ))
                .font(.headline.weight(.semibold))
                .tint(SBColor.accent)
            }
            .padding(.top, 16)
        } label: {
            Label(appState.t("filters.title"), systemImage: "chevron.right")
                .font(.title3.weight(.heavy))
                .foregroundStyle(SBColor.muted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .sbPremiumGlass(radius: SBRadius.lg, interactive: true)
        .sbSoftShadow()
    }

    private var routeAction: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Image(systemName: "bolt.fill")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(SBColor.accent)
                    .frame(width: 72, height: 72)
                    .background(SBColor.electricBlue)
                    .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text(appState.t("home.insight_kicker"))
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(SBColor.muted)
                    Text(appState.t("home.insight_title", ["range": "\(safeRangeKm)"]))
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(SBColor.ink)
                        .lineLimit(2)
                    Text(appState.t("summary.safe_range_value", [
                        "percent": "\(appState.profile.chargePercent)",
                        "range": "\(safeRangeKm)"
                    ]))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SBColor.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(22)
            .background(LinearGradient.sbSoftPanel)

            Button {
                guard appState.canSearch else { return }
                Haptic.tap()
                Task {
                    await appState.findStations()
                    if !appState.routeCandidates.isEmpty {
                        Haptic.success()
                    }
                }
            } label: {
                Text(appState.isSearching ? appState.t("location.calculating") : appState.t("location.find_charger"))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
                    .background(SBColor.electricBlue)
                    .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
            }
            .buttonStyle(SBPremiumButtonStyle())
            .disabled(!appState.canSearch)
            .opacity(appState.canSearch ? 1 : 0.62)
        }
        .sbPremiumGlass(radius: SBRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                .stroke(SBColor.accent, lineWidth: 10)
        )
        .sbGlowShadow()
    }

    private var safeRangeKm: Int {
        Int(appState.profile.safeRangeKm.rounded())
    }

    private var chargeStatusText: String {
        let percent = min(100, max(1, appState.profile.chargePercent))
        if percent < 25 { return appState.t("charge.low") }
        if percent < 75 { return appState.t("charge.ready") }
        return appState.t("charge.long_range")
    }

    private func preferenceTitle(_ preference: RoutePreference) -> String {
        switch preference {
        case .balanced:
            appState.t("intent.balanced")
        case .nearest:
            appState.t("home.quick_near")
        case .fastest:
            appState.t("home.quick_fast")
        case .economical:
            appState.t("home.quick_value")
        }
    }

    private var manualLocationEntryVisible: Bool {
        if appState.userLocation?.source == .manual { return true }
        if locationManager.lastError != nil || locationRequestTimedOut { return true }
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return !didRequestDeviceLocation
        }
    }

    private var locationWaitingText: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            appState.t("home.location_waiting_authorized")
        case .notDetermined:
            appState.t("home.location_waiting_pending")
        default:
            appState.t("home.location_waiting_failed")
        }
    }

    private func requestDeviceLocation() {
        didRequestDeviceLocation = true
        locationRequestTimedOut = false
        locationManager.requestLocation()
        Task {
            try? await Task.sleep(for: .seconds(4))
            if appState.userLocation?.source != .device {
                locationRequestTimedOut = true
            }
        }
    }

    private var manualLocationForm: some View {
        VStack(spacing: 12) {
            Picker(appState.t("home.location_pick"), selection: $selectedPreset) {
                Text(appState.t("home.location_pick")).tag(Optional<ManualLocationPreset>.none)
                ForEach(ManualLocationPreset.allCases) { preset in
                    Text(preset.title).tag(Optional(preset))
                }
            }
            .pickerStyle(.menu)
            .padding(14)
            .background(SBColor.glass)
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous)
                    .stroke(SBColor.line, lineWidth: 1)
            )
            .onChange(of: selectedPreset) { _, preset in
                guard let preset else { return }
                manualLatitude = preset.latitude
                manualLongitude = preset.longitude
                appState.updateLocation(latitude: preset.latitude, longitude: preset.longitude, source: .manual)
            }

            HStack {
                TextField(appState.t("home.latitude"), value: $manualLatitude, format: .number.precision(.fractionLength(4)))
                    .sbDecimalKeyboard()
                TextField(appState.t("home.longitude"), value: $manualLongitude, format: .number.precision(.fractionLength(4)))
                    .sbDecimalKeyboard()
            }
            .textFieldStyle(.plain)
            .padding(14)
            .background(SBColor.glass)
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous)
                    .stroke(SBColor.line, lineWidth: 1)
            )

            Button {
                Haptic.tap()
                appState.updateLocation(latitude: manualLatitude, longitude: manualLongitude, source: .manual)
            } label: {
                Label(appState.t("home.use_manual_location"), systemImage: "mappin.and.ellipse")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(SBColor.electricBlue)
        }
    }
}

private struct QuickActionStyle: ButtonStyle {
    var active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(active ? SBColor.accent : SBColor.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(active ? SBColor.electricBlue : SBColor.glassStrong.opacity(0.54))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .sbPremiumGlass(radius: 22, interactive: true)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(active ? SBColor.lineStrong : SBColor.line, lineWidth: active ? 2 : 1)
            )
            .sbSoftShadow()
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct ChargeVisual: View {
    var percent: Int
    var statusText: String
    var chargeLabel: String
    var selectedLevelText: String

    private var clampedPercent: Int {
        min(100, max(1, percent))
    }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(SBColor.line, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: Double(clampedPercent) / 100)
                    .stroke(SBColor.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("%\(clampedPercent)")
                        .font(.title.weight(.heavy))
                        .contentTransition(.numericText())
                    Text(chargeLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SBColor.muted)
                }
            }
            .frame(width: 108, height: 108)

            VStack(alignment: .leading, spacing: 12) {
                Text(selectedLevelText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(SBColor.muted)
                Text(statusText)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(SBColor.ink)
                BatteryBar(percent: clampedPercent)
            }
        }
        .padding(16)
        .sbPremiumGlass(radius: SBRadius.lg)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: clampedPercent)
    }
}

private struct BatteryBar: View {
    var percent: Int

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = max(18, proxy.size.width * CGFloat(percent) / 100)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(SBColor.line)
                Capsule()
                    .fill(LinearGradient.sbNeon)
                    .frame(width: fillWidth)
                Capsule()
                    .stroke(SBColor.line, lineWidth: 1)
            }
        }
        .frame(height: 30)
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: percent)
        .overlay(alignment: .trailing) {
            Capsule()
                .fill(SBColor.textSoft)
                .frame(width: 8, height: 18)
                .offset(x: 6)
        }
    }
}

private enum ManualLocationPreset: String, CaseIterable, Identifiable {
    case istanbulKadikoy
    case istanbulMaslak
    case ankaraCankaya
    case izmirAlsancak
    case izmirBuca
    case bursaNilufer
    case antalyaMuratpasa
    case muglaFethiye
    case kocaeliGebze
    case eskisehirOdunpazari
    case konyaSelcuklu
    case adanaSeyhan
    case mersinYenisehir
    case samsunAtakum

    var id: String { rawValue }

    var title: String {
        switch self {
        case .istanbulKadikoy: "İstanbul (Kadıköy)"
        case .istanbulMaslak: "İstanbul (Maslak)"
        case .ankaraCankaya: "Ankara (Çankaya)"
        case .izmirAlsancak: "İzmir (Alsancak)"
        case .izmirBuca: "İzmir (Buca)"
        case .bursaNilufer: "Bursa (Nilüfer)"
        case .antalyaMuratpasa: "Antalya (Muratpaşa)"
        case .muglaFethiye: "Muğla (Fethiye)"
        case .kocaeliGebze: "Kocaeli (Gebze)"
        case .eskisehirOdunpazari: "Eskişehir (Odunpazarı)"
        case .konyaSelcuklu: "Konya (Selçuklu)"
        case .adanaSeyhan: "Adana (Seyhan)"
        case .mersinYenisehir: "Mersin (Yenişehir)"
        case .samsunAtakum: "Samsun (Atakum)"
        }
    }

    var latitude: Double {
        switch self {
        case .istanbulKadikoy: 40.9901
        case .istanbulMaslak: 41.1082
        case .ankaraCankaya: 39.9208
        case .izmirAlsancak: 38.4374
        case .izmirBuca: 38.3844
        case .bursaNilufer: 40.2140
        case .antalyaMuratpasa: 36.8841
        case .muglaFethiye: 36.6217
        case .kocaeliGebze: 40.8028
        case .eskisehirOdunpazari: 39.7667
        case .konyaSelcuklu: 37.9464
        case .adanaSeyhan: 36.9914
        case .mersinYenisehir: 36.8121
        case .samsunAtakum: 41.3452
        }
    }

    var longitude: Double {
        switch self {
        case .istanbulKadikoy: 29.0284
        case .istanbulMaslak: 29.0195
        case .ankaraCankaya: 32.8541
        case .izmirAlsancak: 27.1422
        case .izmirBuca: 27.1748
        case .bursaNilufer: 28.9847
        case .antalyaMuratpasa: 30.7056
        case .muglaFethiye: 29.1164
        case .kocaeliGebze: 29.4307
        case .eskisehirOdunpazari: 30.5256
        case .konyaSelcuklu: 32.4932
        case .adanaSeyhan: 35.3308
        case .mersinYenisehir: 34.6415
        case .samsunAtakum: 36.2496
        }
    }
}
