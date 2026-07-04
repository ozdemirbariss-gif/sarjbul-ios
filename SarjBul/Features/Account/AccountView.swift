import SwiftUI

struct AccountView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Hesap")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("Firebase Auth baglantisi bu katmanda tamamlanacak. Misafir akisi uygulamanin ana degerini engellemez.")
                    .font(.headline)
                    .foregroundStyle(SBColor.muted)
                SBPanel {
                    Label("Favoriler, yorumlar ve durum bildirimleri auth etkinlesince burada acilir.", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.headline)
                        .foregroundStyle(SBColor.ink)
                }
                Spacer()
            }
            .padding(22)
            .background(SBColor.background.ignoresSafeArea())
        }
    }
}

