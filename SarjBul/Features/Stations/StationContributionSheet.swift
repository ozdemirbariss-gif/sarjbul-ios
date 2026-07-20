import SarjBulCore
import SwiftUI

struct StationContributionSheet: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(AuthStore.self) private var auth
    @Environment(StationDataStore.self) private var stationData
    @Environment(\.dismiss) private var dismiss

    let candidate: StationCandidate
    @State private var price: String
    @State private var socket: String
    @State private var address: String
    @State private var lighting: SafetyAnswer
    @State private var camera: SafetyAnswer
    @State private var open24Hours: SafetyAnswer
    @State private var isSubmitting = false

    init(candidate: StationCandidate) {
        self.candidate = candidate
        let price = StationDataQuality.displayValue(
            sourceValue: candidate.station.price,
            field: .price,
            insight: candidate.communityInsight
        )
        let socket = StationDataQuality.displayValue(
            sourceValue: candidate.station.socket,
            field: .socket,
            insight: candidate.communityInsight
        )
        let address = StationDataQuality.displayValue(
            sourceValue: candidate.station.address,
            field: .address,
            insight: candidate.communityInsight
        )
        _price = State(initialValue: StationDataQuality.isUnknown(price) ? "" : price)
        _socket = State(initialValue: StationDataQuality.isUnknown(socket) ? "" : socket)
        _address = State(initialValue: StationDataQuality.isUnknown(address) ? "" : address)
        _lighting = State(initialValue: Self.answer(for: candidate.communityInsight, field: .lighting))
        _camera = State(initialValue: Self.answer(for: candidate.communityInsight, field: .camera))
        _open24Hours = State(initialValue: Self.answer(for: candidate.communityInsight, field: .open24Hours))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(candidate.station.name)
                        .font(.headline.weight(.heavy))
                    Text(settings.t("data_quality.explanation"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(settings.t("data_quality.station_details")) {
                    TextField(settings.t("feed.price"), text: $price)
                        .textInputAutocapitalization(.never)
                    TextField(settings.t("feed.socket"), text: $socket)
                    TextField(settings.t("data_quality.address"), text: $address, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(settings.t("data_quality.night_safety")) {
                    safetyPicker(settings.t("data_quality.lighting"), selection: $lighting)
                    safetyPicker(settings.t("data_quality.camera"), selection: $camera)
                    safetyPicker(settings.t("data_quality.open_24h"), selection: $open24Hours)
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting { ProgressView().padding(.trailing, 6) }
                            Text(settings.t("data_quality.confirm"))
                                .font(.headline.weight(.bold))
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting || contribution.values.isEmpty)
                } footer: {
                    Text(settings.t("data_quality.independent_note"))
                }
            }
            .navigationTitle(settings.t("data_quality.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.t("status.cancel")) { dismiss() }
                }
            }
        }
    }

    private func safetyPicker(_ title: String, selection: Binding<SafetyAnswer>) -> some View {
        Picker(title, selection: selection) {
            ForEach(SafetyAnswer.allCases) { answer in
                Text(answer.title(settings: settings)).tag(answer)
            }
        }
        .pickerStyle(.menu)
    }

    private var contribution: StationContribution {
        var values: [StationDataField: String] = [:]
        let trimmedPrice = price.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSocket = socket.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrice.isEmpty { values[.price] = String(trimmedPrice.prefix(120)) }
        if !trimmedSocket.isEmpty { values[.socket] = String(trimmedSocket.prefix(120)) }
        if !trimmedAddress.isEmpty { values[.address] = String(trimmedAddress.prefix(160)) }
        if let value = lighting.value { values[.lighting] = value }
        if let value = camera.value { values[.camera] = value }
        if let value = open24Hours.value { values[.open24Hours] = value }
        return StationContribution(values: values)
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        if await stationData.submitContribution(
            stationKey: candidate.station.statusKey,
            contribution: contribution,
            auth: auth
        ) {
            Haptic.success()
            dismiss()
        }
    }

    private static func answer(
        for insight: StationCommunityInsight?,
        field: StationDataField
    ) -> SafetyAnswer {
        switch insight?.verification(for: field)?.value.lowercased() {
        case "yes", "evet", "true": .yes
        case "no", "hayir", "hayır", "false": .no
        default: .unknown
        }
    }
}

private enum SafetyAnswer: String, CaseIterable, Identifiable {
    case unknown
    case yes
    case no

    var id: String { rawValue }
    var value: String? { self == .unknown ? nil : rawValue }

    @MainActor
    func title(settings: UserSettingsStore) -> String {
        switch self {
        case .unknown: settings.t("data_quality.unknown")
        case .yes: settings.t("status.yes")
        case .no: settings.t("status.no")
        }
    }
}
