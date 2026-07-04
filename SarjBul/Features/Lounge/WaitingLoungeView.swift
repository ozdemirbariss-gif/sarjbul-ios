import SwiftUI

struct WaitingLoungeView: View {
    @State private var playerY: CGFloat = 0
    @State private var obstacleX: CGFloat = 260
    @State private var running = false
    @State private var score = 0
    @State private var best = UserDefaults.standard.integer(forKey: "voltDashBest")
    @State private var crashed = false

    private let timer = Timer.publish(every: 0.025, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ŞARJ ARASI")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(SBColor.accent)
                Text("Salon")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                Text("Aracın dolarken reflekslerini açık tutan kısa ve sürprizli bir oyun.")
                    .font(.headline)
                    .foregroundStyle(SBColor.muted)
            }

            SBPanel {
                VStack(spacing: 18) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("VOLT DASH")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(SBColor.navy)
                            Text(crashed ? "Çarptın" : running ? "Koşuyor" : "Hazır")
                                .font(.largeTitle.weight(.heavy))
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("SKOR \(score)")
                                .font(.headline.weight(.bold))
                            Text("EN İYİ \(best)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(SBColor.muted)
                        }
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(SBColor.background)

                            Capsule()
                                .fill(LinearGradient.sbPrimary)
                                .frame(width: 44, height: 44)
                                .offset(x: 44, y: -max(0, playerY))
                                .shadow(color: SBColor.accent.opacity(0.4), radius: 16)

                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(SBColor.purple)
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
                    .frame(height: 360)

                    SBPrimaryButton(title: running ? "Zıpla" : "Başlat", systemImage: "bolt.fill") {
                        running ? jump() : start()
                    }
                }
            }
            Spacer()
        }
        .padding(22)
        .background(SBColor.background.ignoresSafeArea())
    }

    private func start() {
        score = 0
        crashed = false
        running = true
        playerY = 0
        obstacleX = 260
    }

    private func jump() {
        guard running else {
            start()
            return
        }
        withAnimation(.spring(response: 0.16, dampingFraction: 0.55)) {
            playerY = 112
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.18)) {
                playerY = 0
            }
        }
    }

    private func tick(width: CGFloat) {
        guard running else { return }
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
            best = max(best, score)
            UserDefaults.standard.set(best, forKey: "voltDashBest")
        }
    }
}

