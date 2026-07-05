import Combine
import SwiftUI

struct WaitingLoungeView: View {
    @Environment(AppState.self) private var appState
    @State private var playerY: CGFloat = 0
    @State private var jumpVelocity: CGFloat = 0
    @State private var obstacleX: CGFloat = 260
    @State private var running = false
    @State private var score = 0
    @State private var best = UserDefaults.standard.integer(forKey: "voltDashBest")
    @State private var crashed = false
    @State private var timerConnection: (any Cancellable)?

    private let timer = Timer.publish(every: 0.025, on: .main, in: .common)

    var body: some View {
        ZStack(alignment: .topLeading) {
            SBScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    gamePanel
                }
                .padding(.horizontal, 22)
                .padding(.top, 94)
                .padding(.bottom, 28)
            }

            SBBackButton {
                appState.tab = .home
            }
            .padding(.leading, 18)
            .padding(.top, 6)
        }
        .onDisappear {
            stopTimer()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ŞARJ ARASI")
                .font(.caption.weight(.heavy))
                .foregroundStyle(SBColor.primaryDeep)
                .textCase(.uppercase)
            Text("Salon")
                .font(SBFont.display(size: 52, weight: .heavy))
                .foregroundStyle(SBColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text("Aracın dolarken reflekslerini açık tutan kısa ve sürprizli bir oyun.")
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
                        Text("VOLT DASH")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(SBColor.primaryDeep)
                        Text(crashed ? "Çarptın" : running ? "Koşuyor" : "Hazır")
                            .font(SBFont.display(size: 36, weight: .heavy))
                            .foregroundStyle(SBColor.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("SKOR \(score)")
                            .font(.headline.weight(.heavy))
                        Text("EN İYİ \(best)")
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

                SBPrimaryButton(title: running ? "Zıpla" : "Başlat", systemImage: "bolt.fill") {
                    running ? jump() : start()
                }
            }
        }
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
            best = max(best, score)
            UserDefaults.standard.set(best, forKey: "voltDashBest")
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
}
