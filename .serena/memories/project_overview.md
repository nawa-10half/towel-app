# Project Overview

## かえたお (Kaetao) — Towel App
タオルの交換タイミングを管理するiOSアプリ。Firebase (Auth/Firestore/Storage) でデータ管理。
家族グループ共有機能あり（招待コード方式）。

## Tech Stack
- **Language**: Swift 5.9 (async/await)
- **UI Framework**: SwiftUI (iOS 17+)
- **Auth**: Firebase Auth (Apple Sign-In + Google Sign-In)
- **DB**: Cloud Firestore (リアルタイムリスナー `addSnapshotListener`)
- **Storage**: Firebase Storage (写真アップロード)
- **State**: `@Observable` (Observation framework) — SwiftData/CloudKit は完全除去済み
- **Notifications**: UserNotifications framework
- **Architecture**: MVVM with `@Observable` Services (Singleton) + ViewModels
- **Project Generation**: XcodeGen (`project.yml` → `.xcodeproj`)
- **Dependencies**: firebase-ios-sdk (SPM), GoogleSignIn-iOS (SPM)

## Key Identifiers
- **Bundle ID**: `com.kaetao-app.TowelApp`
- **Firebase Project**: `kaetao-c43f1`
- **iOS App ID**: `1:157027032087:ios:cdd267ab3bea06d0121052`
- **Display Name**: かえたお！
- **Repository**: https://github.com/nawa-10half/towel-app (Private, branch: `main`)

## AWS / Lambda
- **AWS Account**: `606220590854` (ap-northeast-1)
- **状態診断API**: `towel-condition-assess-nova` (Node.js 22.x, Claude Haiku 4.5)
- **API Gateway**: `1gqyhq717j` → `https://1gqyhq717j.execute-api.ap-northeast-1.amazonaws.com/prod/assess-nova`
- **Alexa Skill Lambda**: `lambda/alexa-skill/` (Node.js, ask-sdk-core + firebase-admin)

## Firebase CLI
- **firebase-tools** v15.6.0 インストール済み (`/opt/homebrew/bin/firebase`)
- Firestore ルール、Storage ルール、Hosting のデプロイはすべて CLI で実行可能
- Firebase設定・セキュリティルール・Hosting はすべて towel-app 側で管理
- よく使うコマンド:
  - `firebase deploy --only firestore:rules` — Firestoreルールデプロイ
  - `firebase deploy --only storage` — Storageルールデプロイ
  - `firebase deploy --only hosting` — Hosting (alexa-auth.html等) デプロイ
  - `firebase firestore:indexes` — インデックス確認
  - `firebase auth:export` — ユーザーエクスポート

## Current Status (2026-02)
- Firebase移行完了。家族グループ共有機能実装済み
- Widget/Siri Intents は一時無効化中（SwiftData依存のため、Firebase対応で再実装予定）
- Amazon Alexa連携 実装済み（スキルID: `amzn1.ask.skill.e2a7d5de-b980-401c-a173-09c8c1c441b1`）

## RN版 (kaetao-app) — 凍結
- **パス**: `/Users/takahironawa/Developer/kaetao-app`
- Firebase設定、セキュリティルール、Lambda APIは両版で共用
