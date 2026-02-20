import SwiftUI

struct JoinGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupService = GroupService.shared
    @State private var inviteCode = ""
    @State private var errorMessage: String?

    private let codeLength = 6

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("招待コード（6文字）", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.title2, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .onChange(of: inviteCode) { _, newValue in
                            // Limit to allowed characters and length
                            let filtered = String(newValue.uppercased().filter {
                                "23456789ABCDEFGHJKLMNPQRSTUVWXYZ".contains($0)
                            }.prefix(codeLength))
                            if filtered != inviteCode {
                                inviteCode = filtered
                            }
                        }
                } header: {
                    Text("招待コードを入力")
                } footer: {
                    Text("グループのメンバーから共有された6文字のコードを入力してください")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        Task {
                            do {
                                try await groupService.joinGroup(inviteCode: inviteCode)
                                errorMessage = nil
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        if groupService.isLoading {
                            HStack {
                                ProgressView()
                                Text("参加中...")
                                    .padding(.leading, 8)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("グループに参加")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(inviteCode.count != codeLength || groupService.isLoading)
                }
            }
            .navigationTitle("グループに参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    JoinGroupView()
}
