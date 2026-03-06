import SwiftUI

struct RootView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loggedOut, .error:
                LoginView()
                    .transition(.opacity)
            case .loading:
                ZStack {
                    // Use flat color matching WindowConfigurator's backgroundColor
                    Color(red: 0.07, green: 0.07, blue: 0.11)
                        .ignoresSafeArea(.all)

                    VStack(spacing: 20) {
                        Spacer()

                        Text("IPTV")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.4, green: 0.5, blue: 1.0), Color(red: 0.6, green: 0.4, blue: 1.0)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )

                        VStack(spacing: 10) {
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 0.35, green: 0.45, blue: 1.0), Color(red: 0.55, green: 0.35, blue: 1.0)],
                                                startPoint: .leading, endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(0, geo.size.width * viewModel.loadingProgress), height: 8)
                                        .animation(.easeInOut(duration: 0.4), value: viewModel.loadingProgress)
                                }
                            }
                            .frame(width: 300, height: 8)

                            Text(viewModel.loadingStatus)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))

                            Text("\(Int(viewModel.loadingProgress * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.3))
                        }

                        Spacer()
                    }
                }
                .toolbar { ToolbarItem { Color.clear } }
                .toolbarBackground(.hidden, for: .windowToolbar)
                .transition(.opacity)
            case .ready:
                HomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: stateKey)
        .task {
            await viewModel.bootstrapIfNeeded()
        }
    }

    /// Simple key to trigger animation on state change
    private var stateKey: String {
        switch viewModel.state {
        case .loggedOut: return "loggedOut"
        case .loading:   return "loading"
        case .ready:     return "ready"
        case .error:     return "error"
        }
    }
}
