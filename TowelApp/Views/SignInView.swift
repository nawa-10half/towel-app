import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @State private var authService = AuthService.shared

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.accent)

                Text("かえたお")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("タオルの交換タイミングを管理")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    authService.handleAppleSignInRequest(request)
                } onCompletion: { result in
                    Task {
                        await authService.handleAppleSignInCompletion(result)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)

                Button {
                    Task {
                        await authService.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "g.circle.fill")
                            .font(.title3)
                        Text("Googleでサインイン")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 24)

            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
                .frame(height: 40)
        }
    }
}

#Preview {
    SignInView()
}
