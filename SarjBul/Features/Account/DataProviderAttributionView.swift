import SwiftUI

struct DataProviderAttributionView: View {
    @Environment(UserSettingsStore.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.t("legal.data_sources"))
                .font(.headline)
            Text(settings.t("legal.data_sources_body"))
                .font(.footnote)
            ProviderLink(title: "EPDK", address: "https://www.epdk.gov.tr/Detay/Icerik/3-0-226/web-servisler")
            ProviderLink(title: "ChargeIQ", address: "https://www.chargeiq.com.tr/tr")
            ProviderLink(title: "© OpenStreetMap contributors · ODbL", address: "https://www.openstreetmap.org/copyright")
            OpenMeteoAttributionView()
        }
        .textSelection(.enabled)
    }
}

struct OpenMeteoAttributionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProviderLink(title: "Open-Meteo · CC BY 4.0", address: "https://open-meteo.com/en/licence")
            ProviderLink(title: "Copernicus DEM GLO-90", address: "https://doi.org/10.5270/ESA-c5d3d65")
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct StationDataAttributionView: View {
    var body: some View {
        ProviderLink(title: "© OpenStreetMap contributors · ODbL", address: "https://www.openstreetmap.org/copyright")
            .font(.caption2)
            .padding(6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct ProviderLink: View {
    let title: String
    let address: String

    var body: some View {
        if let url = URL(string: address) {
            Link(title, destination: url)
        }
    }
}
