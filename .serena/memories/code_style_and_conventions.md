# Code Style and Conventions

## Swift Style
- **Swift 5.9** with modern concurrency (async/await)
- **Naming**: camelCase for properties/methods, PascalCase for types
- **Access Control**: `private` for internal helpers, no explicit `internal`
- **Final classes**: `@Observable final class` for Services
- **No docstrings/comments** on most code — self-documenting style
- **Error messages in Japanese**: UI-facing strings are in Japanese

## SwiftUI Patterns
- Views are `struct` conforming to `View`
- Computed `body` property with `some View` return
- Sub-views extracted as computed properties (e.g., `emptyStateView`, `towelList`)
- No `@Environment(\.modelContext)` — SwiftData完全除去済み

## Firebase / Codable Patterns
- `Codable struct` (NOT `@Model class`)
- `@DocumentID var id: String?` — Firestore自動ID
- `@ServerTimestamp var createdAt: Date?` — サーバー側タイムスタンプ
- `CodingKeys` enum でフィールドマッピング

## MVVM + Service Pattern
- **Services**: `@Observable final class` with `static let shared` (singleton)
  - `AuthService.shared` — 認証
  - `FirestoreService.shared` — Firestore CRUD + リアルタイムリスナー
  - `StorageService.shared` — Firebase Storage (`@MainActor`)
  - `GroupService.shared` — グループ管理 (`@MainActor`)
  - `ConditionCheckService.shared` — Lambda API
  - `NotificationService.shared` — 通知
- **ViewModels**: `@Observable final class`, ビジネスロジック担当
  - ViewModels は Service を直接参照する
- **Views**: Service の published プロパティを直接参照 (`FirestoreService.shared.towels`)

## UI Language
- All user-facing text is in **Japanese**
- Navigation titles, button labels, error messages — all Japanese
