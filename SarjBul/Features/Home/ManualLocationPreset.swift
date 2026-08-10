import Foundation

enum ManualLocationPreset: String, CaseIterable, Identifiable {
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
