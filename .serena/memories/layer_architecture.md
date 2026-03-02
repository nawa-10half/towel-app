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

## 依存集中度（参照ファイル数）

```
FirestoreService.shared      ██████████  8 ファイル (ViewModels×2, Views×4, Services×2)
GroupService.shared          ██████      6 ファイル (Views×2, ContentView, Services×3)
AuthService.shared           ████        4 ファイル
StorageService.shared        ████        4 ファイル
NotificationService.shared   ████        4 ファイル
ConditionCheckService.shared ██          1 ファイル (TowelDetailViewModelのみ)
```

## 構造的ホットスポット

### ① `FirestoreService.towelsCollection()` [FirestoreService.swift:27]
- ファイル内で **12箇所** から呼ばれる内部メソッド
- `GroupService.shared.groupId` の有無でパスを即時切替
- ここが壊れると全 CRUD + リスナーが機能不全になる

### ② `AuthService.signOut()` / `deleteAccount()` [AuthService.swift]
- `signOut()`: `FirestoreService.stopListening()` → `GroupService.stopListening()` を連鎖
- `deleteAccount()`: `GroupService.handleAccountDeletion()` → `StorageService.deleteAllUserPhotos()` → `FirestoreService.deleteAllTowels()/deleteUserDocument()` を連鎖
- **実行順序依存**のため変更時は必ず全連鎖を追う

### ③ `TowelDetailViewModel.assessCondition()` [TowelDetailViewModel.swift:35付近]
- `ConditionCheckService`（Lambda）→ `FirestoreService`（保存）→ `StorageService`（写真 Upload）を直列に実行
- 非同期処理が最も密集。エラーハンドリングの抜け漏れが起きやすい

### ④ `ContentView` の `.task` ブロック [ContentView.swift:27付近]
- `GroupService.shared.loadGroupForCurrentUser()` → `firestoreService.startListening()`
- 起動時のリスナー開始シーケンス。遅延するとスプラッシュ後が空になる
