import SwiftUI
import AuthenticationServices

struct AppleReauthView: View {
    @State private var authService = AuthService.shared
    var onSuccess: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("本人確認が必要です")
                .font(.title2)
                .fontWeight(.bold)

            Text("アカウントを削除するには、Appleで再度サインインして本人確認を行う必要があります。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            SignInWithAppleButton(.continue) { request in
                authService.handleAppleSignInRequest(request)
            } onCompletion: { result in
                Task {
                    let success = await authService.reauthenticateWithApple(result)
                    if success {
                        onSuccess()
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 24)

            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}
