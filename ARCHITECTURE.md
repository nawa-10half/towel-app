# かえたお (Kaetao) — アーキテクチャ設計書

> タオルの交換タイミングを管理する iOS アプリ
> 最終更新: 2026-02-25 / commit `0a93474`

---

## 1. システム全体構成

```
┌──────────────────────────────────────────────────────┐
│                    iOS App (SwiftUI)                  │
│                     iOS 17.0+                        │
│                                                      │
│   Views ──→ ViewModels ──→ Services ──→ Models       │
│                               │                      │
│                    ┌──────────┼──────────┐            │
│                    ▼          ▼          ▼            │
│               Firebase   AWS Lambda   Local          │
│              Auth/FS/St   (API GW)   Keychain        │
└──────────────────────────────────────────────────────┘
          │                    │
          ▼                    ▼
┌─────────────────┐  ┌──────────────────────────────────────────────┐
│    Firebase      │  │              AWS                             │
│  (kaetao-c43f1)  │  │                                              │
│                  │  │  ap-northeast-1:                              │
│  - Auth          │  │    restore-code-auth     (認証)              │
│  - Firestore     │  │    towel-alexa-device-link (Alexa連携)       │
│  - Storage       │  │    towel-condition-assess-nova (AI診断)      │
│  - Hosting       │  │                                              │
│                  │  │  us-east-1:                                   │
│                  │  │    alexa-skill-kaetao     (Alexaスキル)      │
└─────────────────┘  └──────────────────────────────────────────────┘
                              │
                              ▼
                     ┌─────────────────┐
                     │  Amazon Alexa    │
                     │  スキル連携      │
                     └─────────────────┘
```

---

## 2. 技術スタック

| カテゴリ | 技術 | バージョン / 備考 |
|---|---|---|
| **UI** | SwiftUI | iOS 17+ / `@Observable` |
| **認証** | Firebase Auth | Custom Token (リストアコード方式) |
| **DB** | Cloud Firestore | リアルタイムリスナー / オフライン対応 |
| **ストレージ** | Firebase Storage | 写真アップロード (JPEG, max 800px) |
| **ホスティング** | Firebase Hosting | 静的ページ (認証・ポリシー等) |
| **AI** | Amazon Bedrock | Claude Haiku 4.5 (状態診断) |
| **音声** | Alexa Skills Kit | ask-sdk-core (Node.js) |
| **Lambda** | AWS Lambda | Node.js 22.x (4関数) |
| **API** | API Gateway | REST, ステージ: `prod` |
| **ビルド** | XcodeGen | `project.yml` → `.xcodeproj` 自動生成 |
| **依存管理** | Swift Package Manager | firebase-ios-sdk 11.0+ |
| **通知** | UserNotifications | ローカル通知 (交換リマインダー) |
| **ネットワーク監視** | Network.framework | `NWPathMonitor` |

---

## 3. iOS アプリ アーキテクチャ

### 3.1 レイヤー構成 (MVVM + Singleton Services)

```
┌─────────────────────────────────────────────┐
│  Views (SwiftUI)                            │
│  画面描画 / ユーザー操作                     │
├─────────────────────────────────────────────┤
│  ViewModels (@Observable)                   │
│  画面ロジック / 状態管理                     │
├─────────────────────────────────────────────┤
│  Services (Singleton, @Observable @MainActor)│
│  ビジネスロジック / Firebase通信             │
├─────────────────────────────────────────────┤
│  Models (Codable structs)                   │
│  Firestore ドキュメントマッピング            │
└─────────────────────────────────────────────┘
```

**特徴**:
- Services は `static let shared` のシングルトン。View/ViewModel から直接参照
- `@Observable` (Observation framework) で SwiftUI と自動同期
- `@MainActor` で UI スレッド安全性を保証

### 3.2 Services 一覧

| サービス | 役割 | パターン |
|---|---|---|
| `AuthService` | 認証 (リストアコード / Keychain / Alexa連携コード) | `@Observable @MainActor` Singleton |
| `FirestoreService` | タオル CRUD / リアルタイムリスナー / 交換記録 / 状態診断結果 | `@Observable @MainActor` Singleton |
| `GroupService` | 家族グループ CRUD / 招待コード / タオル移行 | `@Observable @MainActor` Singleton |
| `StorageService` | 写真アップロード / 削除 / コピー | `@MainActor` Singleton (状態なし) |
| `ConditionCheckService` | AI 状態診断 API 呼び出し | `@unchecked Sendable` Singleton |
| `NotificationService` | ローカル通知スケジュール / キャンセル | `@unchecked Sendable` Singleton |
| `NetworkMonitor` | オンライン/オフライン監視 | `@Observable @MainActor` Singleton |

### 3.3 画面遷移

```
App起動
 ├── OnboardingView (初回のみ / 4ページ)
 │    └── 完了 → hasSeenOnboarding = true
 ├── SplashView (1.2秒 / アニメーション)
 ├── SignInView (未認証時)
 │    ├── 新規: コード表示 → 表示名入力 → Lambda認証
 │    └── 復元: コード入力 → Lambda認証
 └── ContentView (認証済み / TabView)
      ├── [Tab 1] TowelListView
      │    ├── TowelRowView (各行)
      │    ├── TowelFormView (sheet: 追加)
      │    ├── ExchangeRecordSheet (swipe → sheet: 交換記録)
      │    └── TowelDetailView (tap → push)
      │         ├── TowelFormView (sheet: 編集)
      │         ├── CameraPickerView (fullScreenCover: 写真撮影)
      │         ├── ConditionCheckRowView (診断結果行)
      │         └── ConditionCheckDetailView (push: 詳細)
      └── [Tab 2] SettingsView
           ├── アカウント (表示名 / リストアコード / サインアウト)
           ├── GroupSettingsView (グループ作成・管理・退出)
           │    └── JoinGroupView (sheet: 招待コード入力)
           ├── 通知設定 (時刻 / ON/OFF)
           ├── Alexa連携 (コード生成)
           └── アカウント削除
```

---

## 4. データモデル

### 4.1 Firestore コレクション構造

```
firestore/
├── /users/{userId}                          # ユーザー情報
│   ├── displayName: String
│   ├── groupId: String?                     # グループ所属時
│   ├── /towels/{towelId}                    # タオル (ソロモード)
│   │   ├── /records/{recordId}              # 交換記録
│   │   └── /conditionChecks/{checkId}       # AI状態診断結果
│   └── /dailyAssessments/{yyyy-MM-dd}       # 日次診断カウント
│       └── count: Int
│
├── /groups/{groupId}                        # 家族グループ
│   ├── name, inviteCode, createdBy, memberCount
│   ├── /members/{userId}                    # メンバー
│   │   └── displayName, role ("owner"/"member")
│   └── /towels/{towelId}                    # タオル (グループモード)
│       ├── /records/{recordId}
│       └── /conditionChecks/{checkId}
│
├── /inviteCodes/{code}                      # グループ招待コード → groupId
├── /restoreCodes/{code}                     # リストアコード → uid (Admin SDK管理)
└── /linkingCodes/{code}                     # Alexa連携コード → uid, expiresAt (10分)
```

### 4.2 モデル定義

```swift
// --- Towel ---
struct Towel: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var location: String
    var iconName: String               // SF Symbols名
    var exchangeIntervalDays: Int      // 1〜30日
    var lastExchangedAt: Date?
    @ServerTimestamp var createdAt: Date?
    @ServerTimestamp var updatedAt: Date?
    // ローカルのみ (CodingKeys除外):
    var records: [ExchangeRecord]
    var conditionChecks: [ConditionCheck]
    // 計算プロパティ:
    var status: TowelStatus            // .ok / .soon / .overdue
}

// --- ExchangeRecord ---
struct ExchangeRecord: Codable, Identifiable {
    @DocumentID var id: String?
    @ServerTimestamp var exchangedAt: Date?
    var note: String?
}

// --- ConditionCheck ---
struct ConditionCheck: Codable, Identifiable {
    @DocumentID var id: String?
    @ServerTimestamp var checkedAt: Date?
    var photoURL: String?              // Firebase Storage URL
    var overallScore: Int              // 0〜100
    var colorFadingScore: Int          // 色褪せ
    var stainScore: Int                // 汚れ
    var fluffinessScore: Int           // ふわふわ感
    var frayingScore: Int              // ほつれ
    var comment: String
    var recommendation: String
}

// --- FamilyGroup / GroupMember ---
struct FamilyGroup: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var inviteCode: String             // 6文字
    var createdBy: String
    var memberCount: Int
}

struct GroupMember: Codable, Identifiable {
    @DocumentID var id: String?        // = userId
    var displayName: String?
    var role: String                   // "owner" | "member"
}
```

### 4.3 Storage パス

```
Firebase Storage:
├── users/{userId}/towels/{towelId}/conditions/{checkId}.jpg     # ソロ
└── groups/{groupId}/towels/{towelId}/conditions/{checkId}.jpg   # グループ
```

画像仕様: JPEG, 最大 800px, 品質 0.7

---

## 5. 認証設計

### リストアコード方式

Apple / Google Sign-In を廃止し、独自のリストアコード認証を採用。

```
┌─────────┐     POST /restore-auth      ┌──────────┐
│ iOS App  │ ──────────────────────────→ │  Lambda   │
│          │   { code, newUser? }        │           │
│          │                             │  Firestore│
│          │ ←────────────────────────── │  lookup   │
│          │   { customToken }           │           │
│          │                             │  Admin SDK│
│ signIn   │                             │  token生成│
│ WithCustom│                            └──────────┘
│ Token()  │
└─────────┘
```

| 項目 | 仕様 |
|---|---|
| コード形式 | `XXXX-XXXX-XXXX` (12文字 + ハイフン) |
| 文字セット | `23456789ABCDEFGHJKLMNPQRSTUVWXYZ` (紛らわしい文字除外) |
| 保存先 | iOS Keychain (`kSecClassGenericPassword`) |
| 自動サインイン | Keychain にコードがあれば起動時に自動実行 |
| フラグ制御 | `hasAttemptedAutoSignIn` (重複防止), `wasSignedOut` (明示的サインアウト判定) |

---

## 6. 主要機能の設計

### 6.1 リアルタイムデータ同期

`FirestoreService` が 3 階層のリスナーを動的管理:

```
towelListener (コレクション全体)
 └── 各タオルに対して:
      ├── recordListeners[towelId]          (交換記録)
      └── conditionCheckListeners[towelId]  (状態診断)
```

- タオルの追加/削除に応じてサブリスナーを自動 attach / detach
- リスナーの変更は即座に `@Observable` 経由で UI に反映

### 6.2 デュアルパス (ソロ / グループ自動切替)

```swift
// FirestoreService
private func towelsCollection() -> CollectionReference? {
    if let groupId = GroupService.shared.groupId {
        return db.collection("groups").document(groupId).collection("towels")
    }
    return db.collection("users").document(userId).collection("towels")
}
```

`GroupService.shared.groupId` の有無で Firestore / Storage のパスを自動切替。
グループ参加/退出時にリスナーを再接続してシームレスに切り替わる。

### 6.3 オフライン対応

Firestore の CRUD 操作は **非 async** で実行:
- `addDocument()`, `updateData()`, `delete()` はローカルキャッシュに即反映
- ネットワーク復旧時に Firestore SDK が自動同期
- `NetworkMonitor` で接続状態を監視し、オフラインバナーを表示

### 6.4 AI 状態診断

```
┌─────────┐    POST (base64 image)     ┌──────────────────┐
│ iOS App  │ ────────────────────────→  │ Lambda            │
│          │                            │ (Bedrock)         │
│          │ ←──────────────────────── │ Claude Haiku 4.5  │
│          │   JSON scores + comment    │ 温度 0.3          │
└─────────┘                            └──────────────────┘
```

- 4 項目を 100 点満点で評価: 色褪せ / 汚れ / ふわふわ感 / ほつれ
- 日次制限: 2 回/日 (`/dailyAssessments/{date}` でカウント)
- 写真は診断後に Firebase Storage にアップロード → Firestore に URL 保存

### 6.5 家族グループ共有

```
作成者 ──→ グループ作成 ──→ 招待コード (6文字) 発行
                                  │
他メンバー ──→ コード入力 ──→ グループ参加
```

- 最大 10 名まで参加可能
- グループ参加時: 個人タオルをグループにコピー移行 (写真含む)
- グループ退出時: 最後のメンバーならグループ削除
- セキュリティルールの制約により、参加は 2 ステップ (メンバー追加 → Batch 更新)

### 6.6 Alexa 連携

```
┌─────────┐  コード生成   ┌──────────────┐  コード入力   ┌─────────────┐
│ iOS App  │ ──────────→ │ Firestore     │ ←─────────── │ alexa-auth   │
│          │  6文字/10分   │ /linkingCodes │              │ .html        │
└─────────┘              └──────────────┘              └──────┬──────┘
                                                              │
                              POST /alexa-link                │
                         ┌────────────────────┐               │
                         │ Lambda              │ ←─────────── ┘
                         │ コード検証           │
                         │ refreshToken発行     │ ──→ Alexa (Implicit Grant)
                         └────────────────────┘

┌───────────┐  accessToken(=refreshToken)  ┌──────────────┐
│ Alexa      │ ──────────────────────────→ │ alexa-skill   │
│ Device     │                              │ Lambda        │
│            │ ←────────────────────────── │ (us-east-1)   │
│            │  音声レスポンス               │ Firebase読み書き│
└───────────┘                              └──────────────┘
```

**Alexa インテント**:
| インテント | 機能 |
|---|---|
| LaunchRequest | タオル枚数を読み上げ |
| GetTowelStatusIntent | 各タオルの最終交換日を報告 |
| CheckExchangeDeadlineIntent | 期限切れ/期限間近を警告 |
| RecordExchangeIntent | 交換記録を追加 (複数タオル時は番号選択) |

---

## 7. AWS Lambda 一覧

| 関数名 | リージョン | ランタイム | 用途 | API パス |
|---|---|---|---|---|
| `restore-code-auth` | ap-northeast-1 | Node.js (CJS) | リストアコード認証 → Custom Token 発行 | `/prod/restore-auth` |
| `towel-alexa-device-link` | ap-northeast-1 | Node.js (CJS) | Alexa 連携コード検証 → refreshToken 発行 | `/prod/alexa-link` |
| `towel-condition-assess-nova` | ap-northeast-1 | Node.js (ESM) | AI 状態診断 (Bedrock Claude Haiku 4.5) | `/prod/assess-nova` |
| `alexa-skill-kaetao` | us-east-1 | Node.js (CJS) | Alexa スキルハンドラー | (Alexa 直接呼出し) |

**API Gateway**: `Secrets.xcconfig` で設定（git管理外）
**共通依存**: `firebase-admin` (Admin SDK)

---

## 8. Firebase Hosting

| パス | 内容 |
|---|---|
| `/alexa-auth` | Alexa アカウントリンクページ (コード入力 UI) |
| `/privacy-policy` | プライバシーポリシー |
| `/terms-of-use` | 利用規約 |
| `/support` | サポートページ |
| `/delete-account` | アカウント削除案内 |

ホスト: `kaetao-c43f1.web.app`

---

## 9. セキュリティルール (Firestore)

| コレクション | read | write | 備考 |
|---|---|---|---|
| `/users/{userId}` | 本人のみ | 本人のみ | |
| `/users/{userId}/towels/**` | 本人のみ | 本人のみ | サブコレクション含む |
| `/users/{userId}/dailyAssessments/**` | 本人のみ | 本人のみ | |
| `/groups/{groupId}` | 全認証ユーザー | create: 全認証 / update,delete: メンバー | join 時に memberCount 確認が必要なため read は全体許可 |
| `/groups/{groupId}/members/**` | メンバー | 本人のみ (create/delete/update) | |
| `/groups/{groupId}/towels/**` | メンバー | メンバー | `isMember()` 関数で判定 |
| `/inviteCodes/{code}` | 全認証ユーザー | 全認証ユーザー | |
| `/restoreCodes/{code}` | なし (Admin SDK) | delete: 本人のみ | Lambda 経由でのみ作成・読取 |
| `/linkingCodes/{code}` | 本人のみ | create: 本人のみ | 10 分 TTL |

**Storage**: `/users/{userId}/**` は本人のみ、`/groups/{groupId}/**` は全認証ユーザー (Storage では membership 確認不可)

---

## 10. ローカル通知

| 設定 | デフォルト | 保存先 |
|---|---|---|
| 通知 ON/OFF | ON | UserDefaults |
| 通知時刻 | 8:00 | UserDefaults |
| 期限切れ通知 | ON | UserDefaults |

- 通知 ID: `towel-{towelId}` でタオルごとに管理
- 交換期限日に `UNCalendarNotificationTrigger` でスケジュール
- 期限切れタオルは即時 (5 秒後) トリガー

---

## 11. 一時無効化中の機能

| 機能 | 理由 | 再実装方針 |
|---|---|---|
| iOS Widget | SwiftData 依存 | App Groups キャッシュ方式で再実装予定 |
| Siri / App Intents | SwiftData 依存 | Firebase 対応で再実装予定 |

---

## 12. 外部サービス・アカウント

| サービス | ID / URL |
|---|---|
| Firebase Project | `kaetao-c43f1` |
| iOS Bundle ID | `com.kaetao-app.TowelApp` |
| AWS アカウント | `606220590854` |
| API Gateway | `Secrets.xcconfig` で設定 (ap-northeast-1) |
| Alexa Skill ID | `amzn1.ask.skill.e2a7d5de-b980-401c-a173-09c8c1c441b1` |
| Firebase Hosting | `kaetao-c43f1.web.app` |
| GitHub | `github.com/nawa-10half/towel-app` (Private) |

---

## 13. 開発・デプロイ

```bash
# Xcode プロジェクト生成
xcodegen generate

# Firebase ルールデプロイ
firebase deploy --only firestore:rules
firebase deploy --only storage
firebase deploy --only hosting

# Lambda デプロイ
cd lambda/<function-name>
zip -r ../<name>.zip .
aws lambda update-function-code --function-name <name> --zip-file fileb://../<name>.zip
```

---

## 14. 設計上の判断・トレードオフ

| 判断 | 理由 |
|---|---|
| Apple/Google Sign-In 廃止 → リストアコード方式 | 審査対応の簡略化、Alexa 連携との親和性、ユーザー体験の統一 |
| Firestore CRUD を非 async 化 | オフラインファーストの UX。ローカルキャッシュ即反映 + 自動同期 |
| グループ参加を 2 ステップに分割 | Firestore セキュリティルールの atomic 評価で `isMember()` が参加前に false を返す問題の回避 |
| Storage のグループパスを全認証ユーザー許可 | Storage ルールでは Firestore のメンバーシップを確認できないため。リスク許容の上で簡略化 |
| アカウント削除時にグループタオルを残置 | 他メンバーの共有データとして引き継ぎ。プライバシーリスクは許容範囲と判断 |
| Alexa Lambda を us-east-1 に配置 | Alexa Skills Kit が ap-northeast-1 非対応のため |
| AI 診断に Bedrock (Claude Haiku 4.5) を採用 | Anthropic API 直接より AWS 統合が容易。コスト効率が良い |
| 日次診断制限 (2 回/日) | API コスト管理。将来的に Pro プランで上限解放予定 |
