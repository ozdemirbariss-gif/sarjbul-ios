import LinkPresentation
import MapKit
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct StationStoryContent {
    let coordinate: CLLocationCoordinate2D
    let headline: String
    let stationLabel: String
    let stationName: String
    let operatorName: String
    let distanceText: String
    let arrivalText: String
    let scoreText: String
    let footer: String
}

struct StationStoryShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let title: String
}

struct StationStoryShareSheet: UIViewControllerRepresentable {
    let item: StationStoryShareItem

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityItem = StationStoryActivityItem(item: item)
        let controller = UIActivityViewController(
            activityItems: [activityItem],
            applicationActivities: nil
        )
        controller.view.accessibilityIdentifier = "station-story-share-sheet"
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct StationStoryPreviewSheet: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let item: StationStoryShareItem
    @State private var sharePresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                SBColor.background.ignoresSafeArea()

                VStack(spacing: 18) {
                    Image(uiImage: item.image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                                .stroke(SBColor.line, lineWidth: 1)
                        )
                        .shadow(color: SBColor.signal.opacity(0.12), radius: 24, y: 10)
                        .accessibilityLabel(settings.t("story.preview_title"))

                    SBPrimaryButton(
                        title: settings.t("story.share_action"),
                        systemImage: "square.and.arrow.up"
                    ) {
                        Haptic.tap()
                        sharePresented = true
                    }
                    .accessibilityIdentifier("station-story-confirm-share-button")
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
            }
            .navigationTitle(settings.t("story.preview_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.t("status.cancel")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("station-story-preview")
        .sheet(isPresented: $sharePresented) {
            StationStoryShareSheet(item: item)
        }
    }
}

private final class StationStoryActivityItem: NSObject, UIActivityItemSource {
    let item: StationStoryShareItem

    init(item: StationStoryShareItem) {
        self.item = item
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        item.image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        item.image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.png.identifier
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = item.title
        metadata.imageProvider = NSItemProvider(object: item.image)
        return metadata
    }
}

@MainActor
enum StationStoryRenderer {
    private static let canvasSize = CGSize(width: 1_080, height: 1_920)
    private static let mapSize = CGSize(width: 1_080, height: 1_160)
    private static let signal = UIColor(sbHex: SBGeneratedTokens.primary.hex)
    private static let background = UIColor(sbHex: SBGeneratedTokens.background.hex)
    private static let surface = UIColor(sbHex: SBGeneratedTokens.surface.hex)
    private static let ink = UIColor(sbHex: SBGeneratedTokens.text.hex)
    private static let muted = UIColor(sbHex: SBGeneratedTokens.textMuted.hex)

    static func render(_ content: StationStoryContent) async throws -> UIImage {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: content.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        )
        options.size = mapSize
        options.scale = 1
        options.mapType = .mutedStandard
        options.showsBuildings = true
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)

        let snapshot = try await MKMapSnapshotter(options: options).start()
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            let cgContext = context.cgContext
            background.setFill()
            cgContext.fill(CGRect(origin: .zero, size: canvasSize))
            snapshot.image.draw(in: CGRect(origin: .zero, size: mapSize))
            drawMapShade(in: cgContext)
            drawMapPin(snapshot: snapshot, coordinate: content.coordinate)
            drawBrandPill()
            drawScorePill(content.scoreText)
            drawStoryPanel(content)
        }
    }

    private static func drawMapShade(in context: CGContext) {
        let colors = [
            UIColor.clear.cgColor,
            background.withAlphaComponent(0.18).cgColor,
            background.cgColor
        ] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 0.54, 1]
        ) else { return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 540, y: 330),
            end: CGPoint(x: 540, y: 1_190),
            options: []
        )
    }

    private static func drawMapPin(snapshot: MKMapSnapshotter.Snapshot, coordinate: CLLocationCoordinate2D) {
        let point = snapshot.point(for: coordinate)
        let pinRect = CGRect(x: point.x - 58, y: point.y - 58, width: 116, height: 116)
        signal.setFill()
        UIBezierPath(ovalIn: pinRect).fill()

        let configuration = UIImage.SymbolConfiguration(pointSize: 50, weight: .black)
        let bolt = UIImage(systemName: "bolt.fill", withConfiguration: configuration)?.withTintColor(
            .black,
            renderingMode: .alwaysOriginal
        )
        bolt?.draw(in: pinRect.insetBy(dx: 31, dy: 28))
    }

    private static func drawBrandPill() {
        let rect = CGRect(x: 62, y: 78, width: 272, height: 86)
        surface.withAlphaComponent(0.94).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 43).fill()

        signal.setFill()
        UIBezierPath(ovalIn: CGRect(x: 82, y: 99, width: 44, height: 44)).fill()
        drawText(
            "ŞarjBul",
            in: CGRect(x: 146, y: 96, width: 164, height: 50),
            font: .systemFont(ofSize: 34, weight: .heavy),
            color: ink
        )
    }

    private static func drawScorePill(_ score: String) {
        let rect = CGRect(x: 734, y: 78, width: 284, height: 86)
        surface.withAlphaComponent(0.94).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 43).fill()
        drawText(
            score.uppercased(),
            in: rect.insetBy(dx: 22, dy: 20),
            font: .systemFont(ofSize: 29, weight: .heavy),
            color: signal,
            alignment: .center
        )
    }

    private static func drawStoryPanel(_ content: StationStoryContent) {
        let panelRect = CGRect(x: 42, y: 960, width: 996, height: 888)
        background.withAlphaComponent(0.98).setFill()
        UIBezierPath(roundedRect: panelRect, cornerRadius: 68).fill()

        signal.setFill()
        UIBezierPath(
            roundedRect: CGRect(x: 88, y: 1_012, width: 138, height: 18),
            cornerRadius: 9
        ).fill()

        drawText(
            content.headline,
            in: CGRect(x: 88, y: 1_070, width: 900, height: 260),
            font: .systemFont(ofSize: 82, weight: .heavy),
            color: ink
        )
        drawText(
            content.stationLabel.uppercased(),
            in: CGRect(x: 88, y: 1_360, width: 900, height: 42),
            font: .systemFont(ofSize: 25, weight: .heavy),
            color: signal
        )
        drawText(
            content.stationName,
            in: CGRect(x: 88, y: 1_414, width: 900, height: 118),
            font: .systemFont(ofSize: 47, weight: .heavy),
            color: ink
        )
        drawText(
            content.operatorName,
            in: CGRect(x: 88, y: 1_530, width: 900, height: 44),
            font: .systemFont(ofSize: 28, weight: .semibold),
            color: muted
        )

        let metrics = [content.distanceText, content.arrivalText, content.scoreText]
        let metricWidth: CGFloat = 282
        for (index, metric) in metrics.enumerated() {
            let rect = CGRect(x: 88 + CGFloat(index) * 300, y: 1_622, width: metricWidth, height: 92)
            surface.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 32).fill()
            drawText(
                metric,
                in: rect.insetBy(dx: 16, dy: 25),
                font: .systemFont(ofSize: 25, weight: .heavy),
                color: ink,
                alignment: .center
            )
        }

        drawText(
            content.footer.uppercased(),
            in: CGRect(x: 88, y: 1_768, width: 900, height: 42),
            font: .systemFont(ofSize: 22, weight: .bold),
            color: muted
        )
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        text.draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ],
            context: nil
        )
    }
}

private extension UIColor {
    convenience init(sbHex: String) {
        let cleaned = sbHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
