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
            description: "Trouvez un vélo Vélam disponible en temps réel à Amiens. Plus de 30 stations à votre disposition."
        ),
        OnboardingPage(
            icon: "location.circle.fill",
            color: .green,
            title: "Stations à proximité",
            description: "Activez la localisation pour voir immédiatement les stations les plus proches de vous."
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            color: .orange,
            title: "Alertes intelligentes",
            description: "Soyez notifié dès qu'un vélo est disponible dans votre station préférée."
        ),
        OnboardingPage(
            icon: "star.circle.fill",
            color: .yellow,
            title: "Vos favoris toujours accessibles",
            description: "Sauvegardez vos stations habituelles et accédez-y en un clin d'œil."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Pages
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Bottom controls
            VStack(spacing: 20) {
                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? Color.blue : Color(.systemGray4))
                            .frame(width: index == currentPage ? 20 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: currentPage)
                    }
                }

                // CTA
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
                        Button("Passer") {
                            requestPermissionsAndFinish()
                        }
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
                Image(systemName: page.icon)
                    .font(.system(size: 70))
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
}
