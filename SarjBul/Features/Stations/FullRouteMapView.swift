import SwiftUI

struct FullRouteMapView: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(SearchCoordinator.self) private var search
    @Environment(NavigationCoordinator.self) private var navigation
    @Environment(AppMessagePresenter.self) private var messages
    @Environment(FrictionTelemetryStore.self) private var frictionTelemetry
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @GestureState private var dragOffset: CGFloat = 0
    @State private var navigationPickerPresented = false
    let session: ActiveRouteMap

    var body: some View {
        GeometryReader { geometry in
            StationMapPreview(
                station: session.candidate.station,
                origin: session.origin,
                route: session.route,
                interactive: true
            )
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ScrollView {
                    summary
                        .padding(20)
                }
                .frame(height: min(geometry.size.height * 0.44, typeSize.isAccessibilitySize ? 420 : 300))
                .background(SBColor.surfaceBase)
                .sbCardContent()
            }
            .offset(y: reduceMotion ? 0 : dragOffset)
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: dragOffset)
        }
        .background(SBColor.surfaceBase.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("full-route-map")
        .accessibilityAction(.escape) { navigation.collapseRouteMap() }
        .confirmationDialog(
            settings.t("feed.choose_navigation"),
            isPresented: $navigationPickerPresented,
            titleVisibility: .visible
        ) {
            externalMapButton(.appleMaps)
            externalMapButton(.googleMaps)
            Button(settings.t("status.cancel"), role: .cancel) {}
        } message: {
            Text(settings.t("feed.choose_navigation_hint"))
        }
        .alert(settings.t("status.error"), isPresented: Binding(
            get: { messages.current != nil },
            set: { if !$0 { messages.dismiss() } }
        )) {
            Button(settings.t("status.ok")) { messages.dismiss() }
        } message: {
            Text(messages.current?.text(language: settings.language) ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Capsule()
                .fill(SBColor.contentSecondary.opacity(0.5))
                .frame(width: 38, height: 5)
                .padding(.top, 10)
                .accessibilityHidden(true)

            HStack(spacing: 12) {
                Button {
                    Haptic.tap()
                    navigation.collapseRouteMap()
                } label: {
                    Label(settings.t("map.return"), systemImage: "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("route-map-minimize")
                Spacer(minLength: 0)
                Image(systemName: "bolt.car.fill")
                    .font(.title3)
                    .foregroundStyle(SBColor.actionPrimary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
        }
        .foregroundStyle(SBColor.contentPrimary)
        .background(SBColor.surfaceBase)
        .sbCardContent()
        .contentShape(Rectangle())
        .simultaneousGesture(minimizeGesture)
        .accessibilityHint(settings.t("map.minimize_hint"))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("route-map-drag-area")
    }

    private var minimizeGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .updating($dragOffset) { value, offset, _ in
                guard value.translation.height > abs(value.translation.width) else { return }
                offset = max(0, value.translation.height)
            }
            .onEnded { value in
                guard value.translation.height > abs(value.translation.width),
                      value.translation.height > 100
                        || (value.translation.height > 35 && value.predictedEndTranslation.height > 180) else { return }
                navigation.collapseRouteMap()
            }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.candidate.station.name)
                    .font(.title3.weight(.heavy))
                Text(session.candidate.station.address)
                    .font(.caption)
                    .foregroundStyle(SBColor.contentSecondary)
                Text("\(session.route.distanceKm.formatted(.number.precision(.fractionLength(1)))) km · "
                    + settings.t("decision.minutes", ["minutes": "\(session.route.estimatedMinutes)"]))
                    .font(.headline.weight(.bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .simultaneousGesture(minimizeGesture)

            HStack(spacing: 8) {
                Button {
                    if let preference = settings.navigationAppPreference {
                        search.startNavigation(to: session.candidate, using: preference)
                    } else {
                        frictionTelemetry.navigationChoicePresented()
                        navigationPickerPresented = true
                    }
                } label: {
                    Label(settings.t("map.open_external"), systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .padding(.horizontal, 12)
                        .foregroundStyle(SBColor.onActionPrimary)
                        .background(SBColor.actionPrimary, in: RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityIdentifier("route-map-start-navigation")

                Menu {
                    externalMapButton(.appleMaps)
                    externalMapButton(.googleMaps)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.bold))
                        .frame(width: 50, height: 50)
                        .background(SBColor.surfaceInteractive, in: RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityLabel(settings.t("feed.change_navigation"))
                .accessibilityIdentifier("route-map-navigation-options")
            }
            .buttonStyle(.plain)
            .disabled(search.isOpeningRoute)

            Text(returnHint)
                .font(.caption)
                .foregroundStyle(SBColor.contentSecondary)

            if !session.route.steps.isEmpty {
                DisclosureGroup(settings.t("map.directions")) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(session.route.steps) { step in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.instruction)
                                Text(step.distanceMeters.formatted(.number.precision(.fractionLength(0))) + " m")
                                    .foregroundStyle(SBColor.contentSecondary)
                            }
                        }
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
            }
        }
        .foregroundStyle(SBColor.contentPrimary)
    }

    private var returnHint: String {
        switch session.externalApp {
        case .appleMaps: settings.t("map.apple_return_hint")
        case .googleMaps: settings.t("map.google_return_hint")
        case nil: settings.t("map.external_hint")
        }
    }

    private func externalMapButton(_ preference: NavigationAppPreference) -> some View {
        Button(settings.t(preference == .appleMaps ? "feed.apple_maps" : "feed.google_maps")) {
            search.startNavigation(to: session.candidate, using: preference)
        }
    }
}

struct ActiveRouteMapBar: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(NavigationCoordinator.self) private var navigation

    var body: some View {
        if let session = navigation.activeRouteMap {
            HStack(spacing: 0) {
                Button {
                    Haptic.tap()
                    navigation.expandRouteMap()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.title3)
                            .foregroundStyle(SBColor.actionPrimary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.candidate.station.name)
                                .font(.subheadline.weight(.bold))
                                .lineLimit(1)
                            Text(settings.t("map.reopen"))
                                .font(.caption)
                                .foregroundStyle(SBColor.contentSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up")
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 10)
                    .padding(.vertical, 12)
                    .frame(minHeight: 64)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("active-route-map-bar")

                Button {
                    navigation.closeRouteMap()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 44, height: 54)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(settings.t("map.close"))
                .accessibilityIdentifier("active-route-map-close")
            }
            .foregroundStyle(SBColor.contentPrimary)
            .buttonStyle(.plain)
            .background(SBColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(SBColor.divider, lineWidth: 1))
            .sbCardContent()
        }
    }
}
