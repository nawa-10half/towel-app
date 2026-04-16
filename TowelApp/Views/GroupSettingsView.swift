import SwiftUI

struct GroupSettingsView: View {
    var onJoinGroupTapped: () -> Void = {}

    @State private var groupService = GroupService.shared
    @State private var showingCreateAlert = false
    @State private var showingLeaveConfirmation = false
    @State private var showingRegenerateConfirmation = false
    @State private var groupName = ""
    @State private var errorMessage: String?

    var body: some View {
        if let group = groupService.group, groupService.groupId != nil {
            groupDetailSection(group)
        } else {
            noGroupSection
        }
    }

    // MARK: - No Group

    private var noGroupSection: some View {
        Section {
            Button {
                groupName = ""
                showingCreateAlert = true
            } label: {
                Label("グループを作成", systemImage: "person.3.fill")
            }

            Button {
                onJoinGroupTapped()
            } label: {
                Label("招待コードで参加", systemImage: "person.badge.plus")
            }

            if groupService.isLoading {
                HStack {
                    ProgressView()
                    Text("処理中...")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("グループ")
        } footer: {
            Text("グループを作成すると、メンバー全員でアイテムを共同管理できます")
        }
        .alert("グループを作成", isPresented: $showingCreateAlert) {
            TextField("グループ名（例: 我が家）", text: $groupName)
            Button("作成") {
                guard !groupName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                Task {
                    do {
                        try await groupService.createGroup(name: groupName.trimmingCharacters(in: .whitespaces))
                        errorMessage = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - Group Detail

    private func groupDetailSection(_ group: FamilyGroup) -> some View {
        Section {
            HStack {
                Label(group.name, systemImage: "person.3.fill")
                    .font(.headline)
            }

            // Invite code
            HStack {
                Text("招待コード")
                Spacer()
                Text(group.inviteCode)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                Button {
                    UIPasteboard.general.string = group.inviteCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            // Members
            DisclosureGroup(String(localized: "メンバー（\(groupService.members.count)名）")) {
                ForEach(groupService.members) { member in
                    HStack(spacing: 10) {
                        UserProfileIconView(
                            iconName: member.iconName ?? UserProfile.defaultIconName,
                            colorName: member.iconColor ?? UserProfile.defaultIconColor,
                            size: 32
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(member.displayName ?? String(localized: "名前未設定"))
                                    .font(.subheadline)
                                if member.role == "owner" {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        Spacer()
                        if let badgeId = member.pinnedBadgeId,
                           let def = AchievementCatalog.definition(for: badgeId) {
                            Image(def.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                        }
                    }
                }
            }

            // Actions
            Button {
                showingRegenerateConfirmation = true
            } label: {
                Label("招待コードを再生成", systemImage: "arrow.clockwise")
            }

            Button(role: .destructive) {
                showingLeaveConfirmation = true
            } label: {
                Label("グループから退出", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
            }

            if groupService.isLoading {
                HStack {
                    ProgressView()
                    Text("処理中...")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("グループ")
        }
        .confirmationDialog("グループから退出しますか？", isPresented: $showingLeaveConfirmation, titleVisibility: .visible) {
            Button("退出", role: .destructive) {
                Task {
                    do {
                        try await groupService.leaveGroup()
                        errorMessage = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("退出するとグループのアイテムが表示されなくなります。データはグループに残ります。")
        }
        .confirmationDialog("招待コードを再生成しますか？", isPresented: $showingRegenerateConfirmation, titleVisibility: .visible) {
            Button("再生成") {
                Task {
                    do {
                        try await groupService.regenerateInviteCode()
                        errorMessage = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("現在の招待コードは無効になり、新しいコードが生成されます。")
        }
    }
}

#Preview {
    Form {
        GroupSettingsView()
    }
}
