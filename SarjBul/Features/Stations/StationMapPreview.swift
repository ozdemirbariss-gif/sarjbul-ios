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
        ZStack(alignment: .bottom) {
            if let image {
                SnapshotImage(image: image)
                    .transition(AnyTransition.opacity)
            } else {
                Rectangle()
                    .fill(SBColor.surface)
                    .overlay {
                        ProgressView()
                            .tint(SBColor.accent)
                    }
            }

            LinearGradient(
                colors: [.clear, SBColor.accent.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            RouteSketch()
        }
        .frame(height: 330)
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

private struct RouteSketch: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            Path { path in
                path.move(to: CGPoint(x: width * 0.52, y: height * 0.98))
                path.addCurve(
                    to: CGPoint(x: width * 0.56, y: height * 0.08),
                    control1: CGPoint(x: width * 0.49, y: height * 0.68),
                    control2: CGPoint(x: width * 0.61, y: height * 0.34)
                )
            }
            .stroke(
                SBColor.electricBlue,
                style: StrokeStyle(lineWidth: 8, lineCap: .round, dash: [12, 12])
            )

            Circle()
                .fill(SBColor.accent)
                .frame(width: 18, height: 18)
                .position(x: width * 0.49, y: height * 0.74)

            Image(systemName: "mappin.circle.fill")
                .font(.title.weight(.heavy))
                .foregroundStyle(.white, SBColor.electricBlue)
                .position(x: width * 0.56, y: height * 0.12)
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
