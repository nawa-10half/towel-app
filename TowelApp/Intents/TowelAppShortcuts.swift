import AppIntents

struct TowelAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordExchangeIntent(),
            phrases: [
                "\(.applicationName)で\(\.$towel)を交換した",
                "\(.applicationName)で\(\.$towel)を交換",
                "\(\.$towel)を交換した \(.applicationName)",
                "\(.applicationName) \(\.$towel)交換記録"
            ],
            shortTitle: "タオル交換記録",
            systemImageName: "arrow.triangle.2.circlepath"
        )

        AppShortcut(
            intent: CheckTowelStatusIntent(),
            phrases: [
                "\(.applicationName)で\(\.$towel)の状態は",
                "\(.applicationName)で\(\.$towel)の状態を確認",
                "\(\.$towel)の状態は \(.applicationName)",
                "\(.applicationName) \(\.$towel)ステータス"
            ],
            shortTitle: "タオル状態確認",
            systemImageName: "info.circle"
        )

        AppShortcut(
            intent: ListOverdueTowelsIntent(),
            phrases: [
                "\(.applicationName)で交換が必要なタオルは",
                "\(.applicationName)で交換リスト",
                "交換が必要なタオル \(.applicationName)",
                "\(.applicationName) 交換チェック"
            ],
            shortTitle: "交換必要一覧",
            systemImageName: "checklist"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .blue
}
