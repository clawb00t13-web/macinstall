import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)

            Text("MacInstall")
                .font(.largeTitle.bold())

            Text("Sign in to sync your setup across Macs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            GoogleSignInButton()
                .disabled(authService.isLoading)
                .onTapGesture { authService.signInWithGoogle() }
                .overlay {
                    if authService.isLoading {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.background.opacity(0.6))
                        ProgressView().progressViewStyle(.circular)
                    }
                }

            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .frame(width: 320, height: 380)
        .padding()
    }
}

// MARK: - Google Button

private struct GoogleSignInButton: View {
    var body: some View {
        HStack(spacing: 10) {
            // Google "G" logo approximated with coloured letters
            Text("G")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
            Text("Sign in with Google")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
        }
        .frame(width: 220, height: 44)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}
