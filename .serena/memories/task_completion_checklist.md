# Task Completion Checklist

タスク完了後に確認すること:

1. **変更の整合性確認**: 修正ファイル間の一貫性
2. **project.yml 変更時**: `xcodegen generate` でプロジェクト再生成
3. **ビルド確認**: Xcode でビルドが通ることを確認
4. **Git Commit**: 変更内容ごとに分けてコミット
   - 特定ファイルを stage (`git add` で個別指定、`git add .` は避ける)
   - 説明的なコミットメッセージ
5. **Push**: `git push origin main`
6. **Firebase デプロイ** (該当時):
   - Firestoreルール変更: `firebase deploy --only firestore:rules` (kaetao-appリポジトリで実行)
   - Storageルール変更: `firebase deploy --only storage`
   - Hosting変更: `firebase deploy --only hosting`
7. **Lambda デプロイ** (該当時):
   - `cd lambda/{function-name} && zip -r ../{name}.zip . && aws lambda update-function-code ...`
8. **ユーザーへ報告**: 変更内容とフォローアップ事項のサマリー

## 注意事項
- `.xcodeproj` はコミットしない (git-ignored, XcodeGenで再生成)
- `node_modules/` はコミットしない (git-ignored)
- `AuthKey_*.p8` はコミットしない (git-ignored)
- 日本語テキストを全UI文字列に使用
- `@Observable` パターンを維持
