import Combine
import SwiftUI

struct WaitingLoungeView: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(NavigationCoordinator.self) private var navigation
    @Environment(LoungeStore.self) private var lounge
    @State private var playerY: CGFloat = 0
    @State private var jumpVelocity: CGFloat = 0
    @State private var obstacleX: CGFloat = 260
    @State private var running = false
    @State private var score = 0
    @State private var crashed = false
    @State private var timerConnection: (any Cancellable)?
    @State private var reminderMinutes = 30
    @State private var reminderMessage: String?
    @State private var reminderScheduled = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 52
    @ScaledMetric(relativeTo: .title) private var statusSize = 36

    private let timer = Timer.publish(every: 0.025, on: .main, in: .common)

    var body: some View {
        ZStack(alignment: .topLeading) {
            SBScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    reminderPanel
                    gamePanel
                }
                .padding(.horizontal, 22)
                .padding(.top, 94)
                .padding(.bottom, 28)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }

            SBBackButton(accessibilityLabel: settings.t("nav.back")) {
                navigation.tab = .home
            }
            .padding(.leading, 18)
            .padding(.top, 6)
        }
        .onDisappear {
            stopTimer()
        }
    }

    private var reminderPanel: some View {
        SBSecondaryPanel {
            VStack(alignment: .leading, spacing: 16) {
                Label(settings.t("reminder.title"), systemImage: "bell.badge")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(SBColor.ink)
                Text(settings.t("reminder.hint"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SBColor.muted)

                Picker(settings.t("reminder.title"), selection: $reminderMinutes) {
                    ForEach([15, 30, 45], id: \.self) { minutes in
                        Text(settings.t("reminder.minutes", ["minutes": "\(minutes)"]))
                            .tag(minutes)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    Haptic.tap()
                    Task { await toggleReminder() }
                } label: {
                    Label(
                        settings.t(reminderScheduled ? "reminder.cancel" : "reminder.set"),
                        systemImage: reminderScheduled ? "bell.slash.fill" : "bell.fill"
                    )
                    .font(.headline.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(reminderScheduled ? SBColor.muted : SBColor.electricBlue)

                if let reminderMessage {
                    Text(reminderMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(reminderScheduled ? SBColor.electricBlue : SBColor.muted)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.t("lounge.kicker"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(SBColor.primaryDeep)
                .textCase(.uppercase)
            Text(settings.t("lounge.title"))
                .font(SBFont.display(size: min(titleSize, 72), weight: .heavy))
                .foregroundStyle(SBColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(settings.t("lounge.subtitle"))
                .font(.headline.weight(.bold))
                .foregroundStyle(SBColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 92)
    }

    private var gamePanel: some View {
        SBPanel {
            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.t("lounge.game_title"))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(SBColor.primaryDeep)
                        Text(gameStatusText)
                            .font(SBFont.display(size: min(statusSize, 50), weight: .heavy))
                            .foregroundStyle(SBColor.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("\(settings.t("lounge.score")) \(score)")
                            .font(.headline.weight(.heavy))
                        Text("\(settings.t("lounge.best")) \(lounge.bestScore)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(SBColor.muted)
                    }
                }

                GeometryReader { proxy in
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [SBColor.surfaceSolid.opacity(0.92), SBColor.accent.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                                    .stroke(SBColor.line, lineWidth: 1)
                            )

                        Capsule()
                            .fill(LinearGradient.sbPrimary)
                            .frame(width: 44, height: 44)
                            .offset(x: 44, y: -max(0, playerY))
                            .sbGlowShadow()

                        RoundedRectangle(cornerRadius: SBRadius.sm, style: .continuous)
                            .fill(SBColor.electricBlue)
                            .frame(width: 34, height: 72)
                            .offset(x: obstacleX, y: 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        jump()
                    }
                    .onReceive(timer) { _ in
                        tick(width: proxy.size.width)
                    }
                }
                .frame(height: 330)

                SBPrimaryButton(title: running ? settings.t("lounge.jump") : settings.t("lounge.start"), systemImage: "bolt.fill") {
                    running ? jump() : start()
                }
            }
        }
    }

    private var gameStatusText: String {
        if crashed { return settings.t("lounge.crashed") }
        if running { return settings.t("lounge.running") }
        return settings.t("lounge.ready")
    }

    private func start() {
        score = 0
        crashed = false
        running = true
        playerY = 0
        jumpVelocity = 0
        obstacleX = 260
        timerConnection?.cancel()
        timerConnection = timer.connect()
    }

    private func jump() {
        guard running else {
            start()
            return
        }
        guard playerY <= 1 else {
            return
        }
        jumpVelocity = 11.8
    }

    private func tick(width: CGFloat) {
        guard running else { return }
        updatePlayerPhysics()
        obstacleX -= 4.4
        if obstacleX < -40 {
            obstacleX = width + CGFloat.random(in: 30...120)
            score += 1
        }

        let playerFrame = CGRect(x: 44, y: 288 - playerY, width: 44, height: 44)
        let obstacleFrame = CGRect(x: obstacleX, y: 288, width: 34, height: 72)
        if playerFrame.intersects(obstacleFrame) {
            running = false
            crashed = true
            stopTimer()
            lounge.bestScore = max(lounge.bestScore, score)
        }
    }

    private func updatePlayerPhysics() {
        guard playerY > 0 || jumpVelocity > 0 else { return }
        playerY = max(0, playerY + jumpVelocity)
        jumpVelocity -= 0.72
        if playerY == 0 {
            jumpVelocity = 0
        }
    }

    private func stopTimer() {
        timerConnection?.cancel()
        timerConnection = nil
    }

    private func toggleReminder() async {
        if reminderScheduled {
            await ChargingReminderService.shared.cancel()
            reminderScheduled = false
            reminderMessage = settings.t("reminder.cancelled")
            return
        }

        do {
            try await ChargingReminderService.shared.schedule(
                afterMinutes: reminderMinutes,
                title: settings.t("reminder.notification_title"),
                body: settings.t("reminder.notification_body")
            )
            reminderScheduled = true
            reminderMessage = settings.t("reminder.scheduled", ["minutes": "\(reminderMinutes)"])
            Haptic.success()
        } catch {
            reminderScheduled = false
            reminderMessage = settings.t("reminder.denied")
        }
    }
}
