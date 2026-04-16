import SwiftUI
import PhotosUI
import AVFoundation
import WidgetKit
import StoreKit

struct TowelDetailView: View {
    let towelId: String
    @State private var viewModel: TowelDetailViewModel
    @State private var showingEditForm = false
    @State private var showingExchangeSheet = false
    @State private var showingCamera = false
    @State private var showingCameraPermissionAlert = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var recordToDelete: ExchangeRecord?
    @State private var conditionCheckToDelete: ConditionCheck?
    @State private var deleteHapticTrigger = false
    @State private var showingPaywall = false
    @State private var paywallFeature: ProFeature = .assessment

    init(towelId: String) {
        self.towelId = towelId
        self._viewModel = State(initialValue: TowelDetailViewModel(towelId: towelId))
    }

    var body: some View {
        Group {
            if let towel = viewModel.towel {
                towelDetailContent(towel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel.towel?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("編集") {
                    showingEditForm = true
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            if let towel = viewModel.towel {
                TowelFormView(towel: towel)
            }
        }
        .sheet(isPresented: $showingExchangeSheet) {
            ExchangeRecordSheet(towelId: towelId, towelName: viewModel.towel?.name ?? "")
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPickerView(image: $capturedImage)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { _, newImage in
            guard let image = newImage else { return }
            processImage(image)
            capturedImage = nil
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    processImage(image)
                }
            }
            selectedPhotoItem = nil
        }
        .alert("カメラへのアクセス", isPresented: $showingCameraPermissionAlert) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("カメラを使用するには、設定からカメラへのアクセスを許可してください。")
        }
        .alert("エラー", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(feature: paywallFeature)
        }
        .onChange(of: viewModel.showingPaywall) { _, show in
            if show {
                paywallFeature = .assessment
                showingPaywall = true
                viewModel.showingPaywall = false
            }
        }
        .sensoryFeedback(.warning, trigger: deleteHapticTrigger)
        .sensoryFeedback(.success, trigger: viewModel.assessmentSucceeded)
        .sensoryFeedback(.error, trigger: viewModel.errorMessage)
        .task {
            await viewModel.loadDailyAssessmentCount()
        }
        .onAppear {
            viewModel.startListening()
            if !AdService.shared.isRewardedAdReady {
                AdService.shared.loadRewardedAd()
            }
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }

    @ViewBuilder
    private func towelDetailContent(_ towel: Towel) -> some View {
        List {
            statusSection(towel)
            actionSection
            conditionCheckSection(towel)
            conditionHistorySection
            historySection
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async { showingCamera = true }
                }
            }
        case .denied, .restricted:
            showingCameraPermissionAlert = true
        @unknown default:
            showingCameraPermissionAlert = true
        }
    }

    private func processImage(_ image: UIImage) {
        guard let imageData = image.jpegDataResized() else { return }
        Task {
            await viewModel.assessCondition(imageData: imageData, image: image)
        }
    }

    private func statusSection(_ towel: Towel) -> some View {
        Section {
            HStack {
                Label(towel.location, systemImage: "mappin")
                Spacer()
                Text("設置場所")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("\(towel.exchangeIntervalDays)日ごと", systemImage: "calendar")
                Spacer()
                Text("交換間隔")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("\(towel.daysSinceLastExchange)日経過", systemImage: "clock")
                Spacer()
                statusBadge(towel)
            }

            if let lastDate = towel.lastExchangedAt {
                HStack {
                    Label(lastDate.formattedLocalized, systemImage: "arrow.counterclockwise")
                    Spacer()
                    Text("最終交換")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Label(towel.nextExchangeDate.formattedDateOnly, systemImage: "arrow.forward")
                Spacer()
                Text("次回交換")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("ステータス")
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                showingExchangeSheet = true
            } label: {
                Label("交換した！", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .tint(.blue)
            .buttonStyle(.borderedProminent)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    @ViewBuilder
    private func conditionCheckSection(_ towel: Towel) -> some View {
        Section {
            if viewModel.isAssessing {
                HStack {
                    ProgressView()
                    Text("診断中...")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            } else {
                if !StoreService.shared.isPro {
                    let baseLimit = ProLimits.maxDailyAssessments(isPro: false)
                    let total = baseLimit + AdService.shared.bonusAssessmentCount
                    let remaining = max(0, total - viewModel.dailyAssessmentCount)
                    Text("3日間の診断: あと\(remaining)回")
                        .font(.caption2)
                        .foregroundStyle(remaining == 0 ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
                }

                Button {
                    checkCameraPermission()
                } label: {
                    Label("カメラで撮影", systemImage: "camera")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .tint(.indigo)
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .disabled(!viewModel.canAssess)
                .opacity(viewModel.canAssess ? 1 : 0.5)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("写真から選択", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .tint(.indigo)
                .buttonStyle(.bordered)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                .disabled(!viewModel.canAssess)
                .opacity(viewModel.canAssess ? 1 : 0.5)

                if viewModel.showAdButton {
                    Button {
                        AdService.shared.showRewardedAd()
                    } label: {
                        Label("広告を見て診断する", systemImage: "play.rectangle")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .tint(.orange)
                    .buttonStyle(.bordered)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } else if !viewModel.canAssess && !StoreService.shared.isPro {
                    Button {
                        paywallFeature = .assessment
                        showingPaywall = true
                    } label: {
                        Label("Proプランで無制限に", systemImage: "star")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .tint(Color.accentColor)
                    .buttonStyle(.bordered)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }

            if let latest = towel.latestConditionCheck {
                NavigationLink {
                    ConditionCheckDetailView(conditionCheck: latest)
                } label: {
                    ConditionCheckRowView(conditionCheck: latest)
                }
            }
        } header: {
            Text("状態診断")
        }
    }

    private var conditionHistorySection: some View {
        Section {
            if viewModel.sortedConditionChecks.isEmpty {
                Text("診断履歴がありません")
                    .foregroundStyle(.secondary)
            } else {
                let limit = ProLimits.maxVisibleConditionChecks(isPro: StoreService.shared.isPro)
                let visibleChecks = Array(viewModel.sortedConditionChecks.prefix(limit))
                ForEach(visibleChecks) { check in
                    NavigationLink {
                        ConditionCheckDetailView(conditionCheck: check)
                    } label: {
                        ConditionCheckRowView(conditionCheck: check)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            conditionCheckToDelete = check
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }

                if !StoreService.shared.isPro && viewModel.sortedConditionChecks.count > limit {
                    Button {
                        paywallFeature = .history
                        showingPaywall = true
                    } label: {
                        Label("Proですべて見る", systemImage: "lock")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                } else if viewModel.hasMoreConditionChecks {
                    Button {
                        viewModel.loadAllConditionChecks()
                    } label: {
                        Label("すべての診断履歴を表示", systemImage: "ellipsis")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                }
            }
        } header: {
            Text("診断履歴")
        }
        .confirmationDialog(
            "診断記録を削除しますか？",
            isPresented: Binding(
                get: { conditionCheckToDelete != nil },
                set: { if !$0 { conditionCheckToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let check = conditionCheckToDelete {
                    viewModel.deleteConditionCheck(check)
                    conditionCheckToDelete = nil
                    deleteHapticTrigger.toggle()
                }
            }
        }
    }

    private var historySection: some View {
        Section {
            if viewModel.sortedRecords.isEmpty {
                Text("交換履歴がありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.sortedRecords) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text((record.exchangedAt ?? .now).formattedLocalized)
                            .font(.subheadline)
                        if let note = record.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let name = exchangerName(for: record) {
                            Text(String(localized: "\(name) が交換"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            recordToDelete = record
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }

                if viewModel.hasMoreRecords {
                    Button {
                        viewModel.loadAllRecords()
                    } label: {
                        Label("すべての交換履歴を表示", systemImage: "ellipsis")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                }
            }
        } header: {
            Text("交換履歴")
        }
        .confirmationDialog(
            "交換記録を削除しますか？",
            isPresented: Binding(
                get: { recordToDelete != nil },
                set: { if !$0 { recordToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let record = recordToDelete {
                    viewModel.deleteRecord(record)
                    recordToDelete = nil
                    deleteHapticTrigger.toggle()
                }
            }
        }
    }

    private func exchangerName(for record: ExchangeRecord) -> String? {
        guard GroupService.shared.groupId != nil else { return nil }
        guard let uid = record.createdBy else { return nil }
        return GroupService.shared.members.first { $0.id == uid }?.displayName
    }

    private func statusBadge(_ towel: Towel) -> some View {
        Text(towel.status.label)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor(for: towel).opacity(0.15))
            .foregroundStyle(statusColor(for: towel))
            .clipShape(Capsule())
    }

    private func statusColor(for towel: Towel) -> Color {
        switch towel.status {
        case .ok: return .green
        case .soon: return .orange
        case .overdue: return .red
        }
    }
}

// MARK: - Exchange Record Sheet

struct ExchangeRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    let towelId: String
    let towelName: String
    @State private var exchangeDate = Date.now
    @State private var exchangeNote = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var saveTrigger = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        String(localized: "交換日時"),
                        selection: $exchangeDate,
                        in: ...Date.now,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } header: {
                    Text("いつ交換しましたか？")
                }

                Section {
                    TextField("メモ（任意）", text: $exchangeNote)
                }
            }
            .navigationTitle("交換記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("記録する") {
                        saveRecord()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
        }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sensoryFeedback(.success, trigger: saveTrigger)
        .sensoryFeedback(.error, trigger: errorMessage)
        .presentationDetents([.medium])
    }

    private func saveRecord() {
        isSaving = true
        do {
            _ = try FirestoreService.shared.addRecord(
                towelId: towelId,
                exchangedAt: exchangeDate,
                note: exchangeNote.isEmpty ? nil : exchangeNote
            )
            WidgetCenter.shared.reloadAllTimelines()
            saveTrigger.toggle()
            var manager = ReviewRequestManager()
            if manager.recordExchangeAndCheckReview() {
                requestReview()
            }
            dismiss()
        } catch {
            isSaving = false
            errorMessage = "交換記録の保存に失敗しました: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        TowelDetailView(towelId: "preview-id")
    }
}
