# Suggested Commands

## XcodeGen
```bash
xcodegen generate    # project.yml → .xcodeproj 再生成
```

## Firebase CLI (firebase-tools v15.6.0)
```bash
# デプロイ (towel-app ルートで実行)
firebase deploy --only firestore:rules    # Firestoreセキュリティルール
firebase deploy --only storage            # Storageセキュリティルール
firebase deploy --only hosting            # Hosting (alexa-auth.html等)

# 情報確認
firebase firestore:indexes                # Firestoreインデックス一覧
firebase auth:export users.json           # ユーザー一覧エクスポート
firebase projects:list                    # プロジェクト一覧

# エミュレータ
firebase emulators:start                  # ローカルエミュレータ起動
```

## AWS CLI
```bash
# Lambda デプロイ
cd lambda/alexa-skill && zip -r ../alexa-skill.zip . && \
aws lambda update-function-code \
  --function-name kaetao-alexa-skill \
  --zip-file fileb://../alexa-skill.zip

cd lambda/towel-condition-assess-nova && zip -r ../towel-condition-assess-nova.zip . && \
aws lambda update-function-code \
  --function-name towel-condition-assess-nova \
  --zip-file fileb://../towel-condition-assess-nova.zip

# ログ確認
aws logs tail /aws/lambda/kaetao-alexa-skill --follow
aws logs tail /aws/lambda/towel-condition-assess-nova --follow
```

## Google Cloud CLI (gcloud v557.0.0)
```bash
gcloud auth login                        # ログイン
gcloud config set project kaetao-c43f1   # プロジェクト設定
gcloud auth print-access-token           # アクセストークン取得 (REST API呼出用)

# Firebase Auth 設定確認
curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "x-goog-user-project: kaetao-c43f1" \
  "https://identitytoolkit.googleapis.com/admin/v2/projects/kaetao-c43f1/config" | python3 -m json.tool

# OAuth クライアント ID (Web): 157027032087-vefld0tvj2ls0k6lhbn7kupfscupi0qr.apps.googleusercontent.com
# OAuth redirect URI の管理はCLI不可 → Google Cloud Console で操作
```

## Git
```bash
git add <specific-files>
git commit -m "description"
git push origin main
```
