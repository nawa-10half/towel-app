# Do Not Touch / 変更時に注意が必要な領域

## 触ってはいけない領域

### `TowelApp.entitlements` / `TowelWidget.entitlements`
- 現在 `project.yml` からリンクされていないが、将来のために保持
- 削除しない

### `.xcodeproj/` ディレクトリ
- XcodeGen で自動生成される（git-ignored）
- 手動編集しない — 変更は `project.yml` 経由で行う

### `GoogleService-Info.plist`
- Firebase設定ファイル。変更不要

### Intents/ ディレクトリ
- SwiftData依存のまま残存。`project.yml` の `excludes: ["Intents/**"]` でビルド除外中
- Firebase対応で再実装するまで変更しない

## 変更時に細心の注意が必要な箇所

### `FirestoreService` (データ基盤、全View/VMから参照)
- `towelsCollection()` — デュアルパス (ソロ/グループ) の切替ロジック
- `startListening()` — リアルタイムリスナーの起動。`ContentView.task` から呼出
- CRUD メソッドの引数変更は多数のViewに波及
- **対応**: メソッドシグネチャ変更前に `find_referencing_symbols` で全参照を確認

### `Towel` モデル (全View/VM/Serviceから参照)
- `Codable struct` with `@DocumentID`, computed properties (`status`, `lastExchangedAt`)
- プロパティの追加/変更/削除は Views, ViewModels, Services すべてに影響
- `records` / `conditionChecks` はサブコレクションとして別管理（Towel structに直接含まない）
- **対応**: プロパティ変更前に `find_referencing_symbols` で全参照確認

### `GroupService` ↔ `FirestoreService` 連携
- `GroupService.shared.groupId` が `FirestoreService.towelsCollection()` のパス決定に使用
- グループ参加/退出時の `startListening()` 再呼出フロー
- **対応**: どちらかを変更する場合、もう一方への影響を必ず確認

### `AuthService` (認証フロー)
- リストアコード方式認証 + アカウント削除
- `deleteAccount()` は GroupService.handleAccountDeletion → FirestoreService.deleteAllTowels/deleteUserDocument → StorageService.deleteAllUserPhotos を連鎖呼出
- `deleteAccount()` は `requiresRecentLogin` エラー時に `reauthenticateWithRestoreCode()` で Lambda 再認証 → リトライする
- `signOut()` は UserDefaults `wasSignedOut` フラグをセット（自動サインイン抑制）
- **対応**: 削除フローの変更は全Serviceの連携を確認

### `TowelDetailViewModel.assessCondition()` (非同期処理の最密集点)
- `ConditionCheckService`（Lambda）→ `FirestoreService`（保存）→ `StorageService`（写真 Upload）を直列実行
- 途中失敗時のロールバック処理が複雑。エラーハンドリングの追加・変更は全ステップを確認
- **対応**: 変更前に `TowelDetailViewModel.swift` の `assessCondition` メソッド全体を読む

### `TowelDetailView` (最も機能が集中するView)
- 交換記録の作成、AI状態診断（カメラ+API）、履歴表示、削除
- 変更時は副作用に注意

### `TowelStatus` enum (`Towel.swift` 内)
- case の追加/削除は `TowelRowView`, `TowelListViewModel` の switch 文に影響

## グループUI遷移の presentation 競合（解決済み 2026-02-25）
- 全操作（作成/参加/退出/コード再生成）で「Attempt to present」警告なし — 実機テスト確認済み
- Bug 1〜3 修正で自然解消
