import MapKit
import SarjBulCore
import SwiftUI

#if os(iOS)
import UIKit
typealias SBMapSnapshotImage = UIImage
#elseif os(macOS)
import AppKit
typealias SBMapSnapshotImage = NSImage
#endif

@MainActor
enum MapSnapshotter {
    private static let cache = NSCache<NSString, SBMapSnapshotImage>()

    static func image(lat: Double, lon: Double, size: CGSize) async -> SBMapSnapshotImage? {
        let key = "\(lat.roundedKey),\(lon.roundedKey),\(Int(size.width))x\(Int(size.height))" as NSString
        if let hit = cache.object(forKey: key) {
            return hit
        }

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
        )
        options.size = size

        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else {
            return nil
        }

        cache.setObject(snapshot.image, forKey: key)
        return snapshot.image
    }
}

struct StationMapPreview: View {
    let station: Station
    @State private var image: SBMapSnapshotImage?

    var body: some View {
        ZStack {
            if let image {
                SnapshotImage(image: image)
                    .transition(AnyTransition.opacity)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        ProgressView()
                            .tint(SBColor.accent)
                    }
            }

            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white, SBColor.electricBlue)
                .sbGlowShadow()
        }
        .frame(height: 210)
        .clipped()
        .animation(.easeOut(duration: 0.25), value: image != nil)
        .task(id: station.id) {
            image = await MapSnapshotter.image(
                lat: station.latitude,
                lon: station.longitude,
                size: CGSize(width: 430, height: 230)
            )
        }
    }
}

private struct SnapshotImage: View {
    let image: SBMapSnapshotImage

    var body: some View {
        #if os(iOS)
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
        #elseif os(macOS)
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
        #else
        EmptyView()
        #endif
    }
}

private extension Double {
    var roundedKey: String {
        String(format: "%.5f", self)
    }
}
