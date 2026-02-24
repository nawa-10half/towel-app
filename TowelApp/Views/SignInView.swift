import SwiftUI

struct SignInView: View {
    @State private var authService = AuthService.shared
    @State private var step: SignInStep = .codeDisplay
    @State private var generatedCode: String = ""
    @State private var displayNameInput: String = ""
    @State private var restoreCodeInput: String = ""
    @State private var isLoading = false
    @State private var codeCopied = false

    enum SignInStep {
        case codeDisplay   // 新規: コード表示
        case displayName   // 新規: 表示名入力
        case restoreInput  // 既存: コード入力
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .codeDisplay:
                codeDisplayView
            case .displayName:
                displayNameView
            case .restoreInput:
                restoreInputView
            }
        }
        .onAppear {
            if let existingCode = authService.restoreCode {
                // サインアウト後など: 既存コードを使って復帰フローへ
                restoreCodeInput = existingCode
                step = .restoreInput
            } else {
                // 新規ユーザー: コードを生成して表示フローへ
                generatedCode = authService.generateRestoreCode()
                step = .codeDisplay
            }
        }
        .onChange(of: step) {
            authService.errorMessage = nil
        }
    }

    // MARK: - Step 1: コード表示

    private var codeDisplayView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                if let icon = UIImage(named: "AppIcon") {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                Text("かえたお")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("タオルの交換タイミングを管理")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("このコードをメモしてください")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text(generatedCode)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .tracking(2)

                    Button {
                        UIPasteboard.general.string = generatedCode
                        codeCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            codeCopied = false
                        }
                    } label: {
                        Label(
                            codeCopied ? "コピーしました" : "コードをコピー",
                            systemImage: codeCopied ? "checkmark" : "doc.on.doc"
                        )
                        .font(.callout)
                    }

                    Text("機種変更や再インストール時に必要です。\n忘れるとデータを復元できません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button {
                    step = .displayName
                } label: {
                    Text("メモしました　→　次へ")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    step = .restoreInput
                } label: {
                    Text("コードをお持ちの方はこちら")
                        .font(.callout)
                        .foregroundStyle(.secondary)
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

    // MARK: - Step 2: 表示名入力

    private var displayNameView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                Text("表示名を設定")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("家族グループで使用される名前です\n後から変更できます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                TextField("表示名（例: お母さん）", text: $displayNameInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .submitLabel(.done)

                Button {
                    Task { await startNewUser() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("はじめる")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(displayNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.accentColor.opacity(0.4)
                        : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(displayNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
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

            Button {
                step = .codeDisplay
            } label: {
                Text("戻る")
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - 既存ユーザー: コード入力

    private var restoreInputView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                Text("コードでサインイン")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("お手持ちのリストアコードを入力してください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                TextField("例: AB12-CD34-EF56", text: $restoreCodeInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .font(.system(.body, design: .monospaced))
                    .submitLabel(.done)

                Button {
                    Task { await restoreSignIn() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("サインイン")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(restoreCodeInput.isEmpty
                        ? Color.accentColor.opacity(0.4)
                        : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(restoreCodeInput.isEmpty || isLoading)
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

            // サインアウト後（既存コードあり）は新規フローに戻る必要がない
            if authService.restoreCode == nil {
                Button {
                    authService.errorMessage = nil
                    step = .codeDisplay
                } label: {
                    Text("戻る")
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 40)
            } else {
                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Actions

    private func startNewUser() async {
        isLoading = true
        defer { isLoading = false }
        await authService.signInWithRestoreCode(generatedCode, isNewUser: true)
        if authService.isAuthenticated {
            try? await authService.ensureUserDocument(displayName: displayNameInput)
        }
    }

    private func restoreSignIn() async {
        isLoading = true
        defer { isLoading = false }
        let code = restoreCodeInput.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        await authService.signInWithRestoreCode(code)
    }
}

#Preview {
    SignInView()
}
