import PhotosUI
import SarjBulCore
import SwiftUI
import UIKit

struct ChargingInsightsView: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(ChargingHistoryStore.self) private var history
    @Environment(FavoritesStore.self) private var favorites
    @Environment(StationDataStore.self) private var stationData
    @Environment(AuthStore.self) private var auth

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var parsedReceipt: ParsedChargingReceipt?
    @State private var selectedStationID: String?
    @State private var isReading = false
    @State private var receiptError: String?
    @State private var energyKWh = 0.0
    @State private var totalCostTRY = 0.0
    @State private var receiptEditorPresented = false
    private let ocr = ReceiptOCRService()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.t("history.title"))
                        .font(.title2.weight(.heavy))
                    Text(settings.t("history.subtitle"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SBColor.muted)
                }
                Spacer(minLength: 8)
                if isReading {
                    ProgressView()
                        .frame(width: 28, height: 28)
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "doc.viewfinder")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(SBColor.ink)
                        .frame(width: 48, height: 48)
                        .background(SBColor.accent)
                        .clipShape(Circle())
                }
                .accessibilityLabel(settings.t("history.scan_receipt"))
            }

            summaryGrid

            HStack(spacing: 10) {
                Label(
                    settings.t("history.province_progress", ["count": "\(summary.visitedProvinces.count)"]),
                    systemImage: "map.fill"
                )
                Spacer()
                ShareLink(item: wrappedText) {
                    Label(settings.t("history.share"), systemImage: "square.and.arrow.up")
                }
            }
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(SBColor.electricBlue)

            collectionProgress

            if let receiptError {
                Text(receiptError)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SBColor.danger)
                    .accessibilityAddTraits(.isStaticText)
            }

            if !history.records.isEmpty {
                Divider().overlay(SBColor.line)
                ForEach(history.records.prefix(3)) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.stationName)
                                .font(.subheadline.weight(.heavy))
                                .lineLimit(1)
                            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(SBColor.muted)
                        }
                        Spacer()
                        Text(String(format: "%.1f kWh · %.0f TL", record.energyKWh, record.totalCostTRY))
                            .font(.caption.weight(.heavy))
                    }
                }
            }
        }
        .padding(20)
        .sbPremiumGlass(radius: SBRadius.xl)
        .sbSoftShadow()
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await readReceipt(item) }
        }
        .sheet(isPresented: $receiptEditorPresented) {
            receiptEditor
        }
    }

    private var summaryGrid: some View {
        HStack(spacing: 10) {
            summaryMetric("\(summary.sessionCount)", settings.t("history.sessions"))
            summaryMetric(String(format: "%.0f TL", summary.totalCostTRY), settings.t("history.spending"))
            summaryMetric(String(format: "%.0f kg", summary.avoidedCO2Kg), settings.t("history.co2"))
        }
    }

    private var collectionProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.t("history.collections"))
                .font(.subheadline.weight(.heavy))

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(ChargingCollections.progress(visitedProvinces: summary.visitedProvinces)) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.isComplete ? "checkmark.seal.fill" : item.symbol)
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(item.isComplete ? SBColor.primaryDeep : SBColor.electricBlue)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(collectionTitle(item.kind))
                                    .font(.caption.weight(.heavy))
                                    .lineLimit(1)
                                Text(item.isComplete
                                     ? settings.t("history.collection_complete")
                                     : settings.t("history.collection_progress", [
                                        "visited": "\(item.visitedCount)",
                                        "total": "\(item.provinces.count)"
                                     ]))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(SBColor.muted)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 58)
                        .sbPremiumGlass(radius: SBRadius.md)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func collectionTitle(_ kind: ChargingCollectionKind) -> String {
        switch kind {
        case .eastExpress:
            settings.t("history.collection_east_express")
        case .aegeanTour:
            settings.t("history.collection_aegean_tour")
        case .blackSeaHighlands:
            settings.t("history.collection_black_sea")
        }
    }

    private func summaryMetric(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(SBColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var receiptEditor: some View {
        NavigationStack {
            Form {
                Section(settings.t("history.receipt_values")) {
                    TextField(settings.t("history.energy"), value: $energyKWh, format: .number)
                        .keyboardType(.decimalPad)
                    TextField(settings.t("history.cost"), value: $totalCostTRY, format: .number)
                        .keyboardType(.decimalPad)
                }

                if !favorites.recentStations.isEmpty {
                    Section(settings.t("history.station")) {
                        Picker(settings.t("history.station"), selection: $selectedStationID) {
                            Text(settings.t("history.station_unknown")).tag(String?.none)
                            ForEach(favorites.recentStations.prefix(12)) { station in
                                Text(station.name).tag(String?.some(station.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle(settings.t("history.confirm_receipt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.t("status.cancel")) { receiptEditorPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("history.save"), action: saveReceipt)
                        .disabled(energyKWh <= 0 || totalCostTRY < 0)
                }
            }
        }
    }

    private var summary: ChargingYearSummary {
        history.summary(profile: settings.profile)
    }

    private var selectedStation: Station? {
        guard let selectedStationID else { return nil }
        return favorites.recentStations.first { $0.id == selectedStationID }
    }

    private var wrappedText: String {
        settings.t("history.wrapped", [
            "year": "\(summary.year)",
            "sessions": "\(summary.sessionCount)",
            "distance": "\(Int(summary.estimatedDistanceKm.rounded()))",
            "co2": "\(Int(summary.avoidedCO2Kg.rounded()))"
        ])
    }

    private func readReceipt(_ item: PhotosPickerItem) async {
        isReading = true
        receiptError = nil
        defer { isReading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let cgImage = image.cgImage else { throw ReceiptOCRService.Error.invalidImage }
            let receipt = try await ocr.recognize(cgImage: cgImage)
            parsedReceipt = receipt
            energyKWh = receipt.energyKWh ?? 0
            totalCostTRY = receipt.totalCostTRY ?? 0
            selectedStationID = favorites.recentStations.first?.id
            receiptEditorPresented = true
        } catch {
            receiptError = settings.t("history.scan_failed")
        }
    }

    private func saveReceipt() {
        let station = selectedStation
        let unitPrice = energyKWh > 0 ? totalCostTRY / energyKWh : parsedReceipt?.unitPriceTRY
        history.add(ChargingSessionRecord(
            stationID: station?.id,
            stationName: station?.name ?? settings.t("history.station_unknown"),
            operatorName: station?.operatorName,
            province: station.flatMap { TurkishProvinceDetector.detect(in: $0.address) },
            energyKWh: energyKWh,
            totalCostTRY: totalCostTRY,
            unitPriceTRY: unitPrice
        ))
        receiptEditorPresented = false
        Haptic.success()

        guard let station, let unitPrice, auth.isAuthenticated else { return }
        Task {
            _ = await stationData.submitContribution(
                stationKey: station.statusKey,
                contribution: StationContribution(values: [
                    .price: String(format: "%.2f TL/kWh", unitPrice)
                ]),
                auth: auth
            )
        }
    }
}
