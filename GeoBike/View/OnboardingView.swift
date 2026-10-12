import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: StationViewModel
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "bicycle.circle.fill",
            color: .blue,
            title: "Bienvenue sur GeoBike",
            description: "Accédez en temps réel aux stations de vélos JCDecaux partout en France — Amiens, Toulouse, Lyon et bien d'autres villes.",
            badge: nil
        ),
        OnboardingPage(
            icon: "map.fill",
            color: .green,
            title: "Carte interactive",
            description: "Repérez toutes les stations sur la carte. La couleur de chaque point indique le nombre de vélos disponibles en ce moment.",
            badge: "Vert = dispo · Rouge = vide"
        ),
        OnboardingPage(
            icon: "location.circle.fill",
            color: .teal,
            title: "Stations à proximité",
            description: "Activez la localisation pour trouver instantanément les stations les plus proches, triées par distance à pied.",
            badge: nil
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            color: .orange,
            title: "Alertes & Favoris",
            description: "Ajoutez vos stations en favoris et activez une alerte : vous serez notifié dès qu'un vélo est disponible.",
            badge: nil
        ),
        OnboardingPage(
            icon: "mappin.and.ellipse",
            color: .purple,
            title: "Votre ville, votre réseau",
            description: "GeoBike détecte automatiquement votre ville au premier lancement. Vous pouvez en changer à tout moment depuis votre profil.",
            badge: "Détection GPS automatique"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            VStack(spacing: 20) {
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.blue : Color(.systemGray4))
                            .frame(width: index == currentPage ? 20 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: currentPage)
                    }
                }

                if currentPage == pages.count - 1 {
                    Button {
                        requestPermissionsAndFinish()
                    } label: {
                        Label("Commencer", systemImage: "bicycle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    HStack {
                        Button("Passer") { requestPermissionsAndFinish() }
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            HStack {
                                Text("Suivant")
                                Image(systemName: "chevron.right")
                            }
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue, in: Capsule())
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 8)
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.12))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(page.color.opacity(0.07))
                    .frame(width: 200, height: 200)
                Image(systemName: page.icon)
                    .font(.system(size: 72))
                    .foregroundStyle(page.color)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let badge = page.badge {
                    Text(badge)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(page.color)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(page.color.opacity(0.12), in: Capsule())
                }
            }

            Spacer()
        }
    }

    private func requestPermissionsAndFinish() {
        viewModel.location.requestPermission()
        Task { await NotificationService.shared.requestPermission() }
        UserDefaults.standard.set(true, forKey: "onboarding_done")
        withAnimation { isPresented = false }
    }
}

struct OnboardingPage {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let badge: String?
}
