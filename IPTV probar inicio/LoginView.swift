import SwiftUI

// MARK: - LoginView

struct LoginView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private var errorText: String? {
        if case let .error(message) = viewModel.state { return message }
        return nil
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(red: 0.06, green: 0.07, blue: 0.13), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "play.tv")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)

                Text("IPTV para macOS")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Canales en vivo · Películas · Series")
                    .foregroundStyle(.white.opacity(0.8))

                VStack(spacing: 14) {
                    darkField("Servidor (ej: http://tu-servidor.com:8880)",
                              text: $viewModel.credentials.serverURL)

                    darkField("Usuario",
                              text: $viewModel.credentials.username)

                    darkSecureField("Contraseña",
                                    text: $viewModel.credentials.password)

                    Toggle("Recordar credenciales en este Mac", isOn: $viewModel.rememberCredentials)
                        .toggleStyle(.switch)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(24)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await viewModel.login() }
                } label: {
                    Text("Entrar")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(
                    viewModel.credentials.serverURL.isEmpty ||
                    viewModel.credentials.username.isEmpty ||
                    viewModel.credentials.password.isEmpty
                )

                if case .error = viewModel.state {
                    Button("Olvidar credenciales guardadas") {
                        viewModel.forgetSavedCredentials()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: 520)
            .padding(28)
        }
    }

    // MARK: - Dark-styled fields

    private func darkField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .modifier(DarkFieldStyle())
    }

    private func darkSecureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .textFieldStyle(.plain)
            .modifier(DarkFieldStyle())
    }
}

// MARK: - Shared dark field styling

private struct DarkFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}
