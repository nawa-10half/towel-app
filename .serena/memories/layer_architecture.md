# Layer Architecture & Dependency Map

## エントリポイント

| エントリポイント | ファイル | 役割 |
|---|---|---|
| **`TowelApp`** | `TowelApp/TowelApp.swift` | `@main` Firebase初期化、認証状態ルーティング (SignInView ↔ ContentView) |

※ Widget/Intents は一時無効化中

## レイヤー構造

```
┌──────────────────────────────────────────────────┐
│  Entry Point                                      │
│  TowelApp(@main) → Firebase.configure()           │
│    ├─ SignInView (未認証時)                         │
│    └─ ContentView (認証済み時)                      │
├──────────────────────────────────────────────────┤
│  Views (SwiftUI struct)                           │
│  ContentView → TabView ルート                      │
│    ├─ TowelListView                               │
│    │    ├─ TowelRowView                           │
│    │    ├─ → TowelDetailView                      │
│    │    │    ├─ → TowelFormView (編集)             │
│    │    │    ├─ ConditionCheckRowView              │
│    │    │    ├─ ConditionCheckDetailView           │
│    │    │    └─ CameraPickerView                  │
│    │    └─ → TowelFormView (新規追加)              │
│    └─ SettingsView                                │
│         ├─ GroupSettingsView → JoinGroupView       │
│         └─ AppleReauthView                        │
├──────────────────────────────────────────────────┤
│  ViewModels (@Observable final class)             │
│  TowelListViewModel  ← TowelListView             │
│  TowelDetailViewModel ← TowelDetailView          │
│    └─ assessCondition() → ConditionCheckService   │
├──────────────────────────────────────────────────┤
│  Services (Singleton, @Observable/@MainActor)     │
│  AuthService.shared        — Firebase Auth        │
│  FirestoreService.shared   — Firestore CRUD +     │
│    addSnapshotListener (towels, records, checks)  │
│  StorageService.shared     — Firebase Storage     │
│  GroupService.shared       — グループ管理/招待コード│
│  ConditionCheckService.shared — Lambda API呼出    │
│  NotificationService.shared — 通知スケジューリング │
├──────────────────────────────────────────────────┤
│  Models (Codable struct)                          │
│  Towel        — @DocumentID id, records/checks は│
│                 サブコレクション (Firestoreリスナー) │
│  ExchangeRecord — @ServerTimestamp exchangedAt    │
│  ConditionCheck — photoURL (Storage URL)          │
│  FamilyGroup / GroupMember — グループ共有          │
│  TowelStatus (enum) — .overdue / .soon / .ok     │
├──────────────────────────────────────────────────┤
│  Utilities                                        │
│  DateExtensions, ImageExtensions                  │
└──────────────────────────────────────────────────┘
```

## データフローのポイント

- **View → Service 直接参照**: `FirestoreService.shared.towels` で `@Observable` 経由でUI自動更新
- **`@Query` / `ModelContext` は不使用**: SwiftData 完全除去済み
- **デュアルパス**: `FirestoreService.towelsCollection()` が `GroupService.shared.groupId` の有無で
  `/users/{uid}/towels` or `/groups/{gid}/towels` を自動切替
- **StorageService** も同様に `conditionPhotoPath()` でソロ/グループを自動切替

## 依存方向
- **View → ViewModel → Service → Firestore** (単方向)
- **View → Service** 直接参照もあり (AuthService, GroupService)
- Model 層は他レイヤーに依存しない
