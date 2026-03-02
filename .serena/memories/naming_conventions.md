# Naming Conventions

## Swift
- **型名**: PascalCase (`Towel`, `ExchangeRecord`, `FamilyGroup`, `GroupMember`)
- **プロパティ/メソッド**: camelCase (`exchangeIntervalDays`, `filteredTowels()`)
- **日本語プロパティ**: `formatted日本語` — Date extension のみ

## ファイル命名パターン
| レイヤー | パターン | 例 |
|---|---|---|
| Model | `{Entity}.swift` | `Towel.swift`, `ExchangeRecord.swift`, `ConditionCheck.swift`, `Group.swift` |
| ViewModel | `{Entity}{Screen}ViewModel.swift` | `TowelListViewModel.swift`, `TowelDetailViewModel.swift` |
| View | `{Entity}{Role}View.swift` | `TowelListView.swift`, `TowelRowView.swift`, `GroupSettingsView.swift` |
| Service | `{Domain}Service.swift` | `AuthService.swift`, `FirestoreService.swift`, `StorageService.swift`, `GroupService.swift` |
| Utility | `{Type}Extensions.swift` | `DateExtensions.swift`, `ImageExtensions.swift` |

## Service の命名規則
- `@Observable final class` で宣言
- `static let shared` で singleton 公開
- メソッド名は動詞始まり (`startListening`, `addTowel`, `uploadConditionPhoto`)
- エラー型は `{Domain}Error` enum (`FirestoreError`, `GroupError`, `StorageError`)

## Enum
- `TowelStatus` — `Towel.swift` 内で定義 (`.overdue`, `.soon`, `.ok`)
- case は lowerCamelCase

## 依存参照パターン
- View から Service を参照するときは `@State private var xService = XService.shared` で保持
- ViewModel は `XService.shared` を直接呼出（DI なし）
- Service 間参照は `XService.shared` 直接呼出（循環に注意: FirestoreService ↔ GroupService は相互参照あり）

## UI テキスト
- ユーザーに見える文字列はすべて日本語
