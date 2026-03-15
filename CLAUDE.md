# Routine-ios — CLAUDE.md

## プロジェクト概要

iPhone + Apple Watch 向けのネイティブアプリ（SwiftUI + watchOS）。
PWA版（routine-app）と Markdown 形式でデータ互換を持ちながら、バックグラウンドタイマー・Watch 通知・Watch UI を実現する。

PWA版リポジトリ: `uruvasi/routine-app`（別リポジトリ・独立して継続）

## スタック

- **Swift + SwiftUI**（iOS 26 / Xcode 26）
- **watchOS** コンパニオンアプリ（`Routine-watch` ターゲット）
- **UserNotifications** — ローカル通知（Watch にもミラーリング）
- **AVFoundation / AudioToolbox** — TTS + システムサウンド
- **WatchConnectivity**（未実装・バックログ）

## ターゲット構成

| ターゲット | 役割 |
|---|---|
| `Routine-ios` | iPhone アプリ本体 |
| `Routine-watch` | Apple Watch コンパニオン（現在プレースホルダー） |

## ファイル構成

```
Routine-ios/
  Routine-ios/
    Routine_iosApp.swift     — @main、通知権限リクエスト
    ContentView.swift        — TabView（ルーティン / 設定）
    Views/
      RoutineListView.swift  — ルーティン一覧・並び替え・削除
      RoutineEditorView.swift — タスク編集・並び替え・時間ピッカー
      RoutineTimerView.swift — タイマー実行（TimerViewModel含む）
      SettingsView.swift     — 言語切替・Export/Import
    Helpers/
      AudioAlertManager.swift — TTS + システムサウンド
  Routine-watch/
    Routine_watchApp.swift   — @main（プレースホルダー）
    ContentView.swift        — Watch UI（プレースホルダー）
  Shared/
    Localization.swift       — L struct（ja/en 文字列）
    Models/
      Routine.swift          — Routine / RoutineTask / AppLanguage 型定義
    Store/
      RoutineStore.swift     — CRUD・並び替え・Markdown Import/Export・UserDefaults 永続化
      SettingsStore.swift    — 言語設定（UserDefaults 永続化）
```

## データモデル

```swift
struct RoutineTask: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var duration: Int  // 秒
}

struct Routine: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var tasks: [RoutineTask]
    var totalDuration: Int  // 計算プロパティ
}

enum AppLanguage: String, Codable, CaseIterable { case ja, en }
```

## タイマー仕様

- `TimerViewModel`（`@MainActor ObservableObject`）がタイマー状態を管理
- `taskEndDate: Date` ベースで残り時間を計算（バックグラウンド復帰時に自動補正）
- タスク完了時に `UNTimeIntervalNotificationTrigger` でローカル通知をスケジュール（Watch にもミラー）
- 音声: タスク開始時にビープ + TTS、完了時に別音
- 自動進行: 時間切れで次のタスクへ

## Export/Import 仕様（PWA と互換）

```markdown
# ルーティン名
- タスク名: X分
- タスク名: X分Y秒
```

- 日本語・英語両フォーマット対応（`parseDuration` で吸収）
- Import: append（既存に追加）または replace（全置換）— **現状 append のみ実装済み、選択 UI は未実装**

## 言語対応

- `AppLanguage` enum（ja / en）
- `L(lang:)` struct で全文字列を一元管理（`Shared/Localization.swift`）
- `SettingsStore` で言語設定を UserDefaults に永続化
- TTS も言語に追従（`AVSpeechSynthesisVoice(language:)`）

## ビルド・開発環境

```bash
# Xcode 26 / iOS 26 / watchOS 26
# Apple Developer Program 登録済み
# Apple Watch 実機あり
```

### ⚠️ 既知の問題（未解決）

**`Ambiguous implicit access level for import of 'SwiftUI'`**

Xcode 26 の Swift upcoming feature `InternalImportsByDefault` が原因。
ビルド設定から `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` を削除済みだが未解消。
Context7 MCP で Xcode 26 の正式対応方法を調査予定。

---

## セッション記録

### 2026-03-15 — セッション1: プロジェクト初期セットアップ + iPhone UI 骨格

1. **リポジトリ作成** `uruvasi/Routine-ios`（GitHub）
2. **Xcode プロジェクト作成**（iOS App + Watch App の2ターゲット構成）
3. **共有データモデル実装**（`Shared/` フォルダ、両ターゲットに追加）
   - `Routine.swift` — Routine / RoutineTask / AppLanguage
   - `RoutineStore.swift` — CRUD・並び替え・Markdown Import/Export
   - `Localization.swift` — ja/en 文字列定義
   - `SettingsStore.swift` — 言語設定永続化
4. **iPhone UI 骨格実装**
   - `ContentView.swift` — TabView（ルーティン / 設定）
   - `RoutineListView.swift` — 一覧・並び替え・削除・実行ボタン
   - `RoutineEditorView.swift` — タスク編集・DurationPickerSheet
   - `RoutineTimerView.swift` — プログレスリング・再生/一時停止/前後ジャンプ
   - `SettingsView.swift` — 言語切替・Export/Import
   - `AudioAlertManager.swift` — TTS + システムサウンド
5. **通知権限リクエスト** を `Routine_iosApp.swift` に追加
6. **Context7 MCP 設定**（`~/.claude/mcp.json`）

**現在の状態:** iPhone UI の骨格は実装済み。ビルドエラー（import access level）が未解消。Watch はプレースホルダーのみ。

---

## バックログ

### 優先度高（次のセッションでやること）

- [ ] **ビルドエラー解消** — Xcode 26 の `InternalImportsByDefault` 対応（Context7 で調査）
- [ ] **実機動作確認** — iPhone 実機でルーティン作成・編集・タイマー実行を確認
- [ ] **Import モード選択 UI** — 「既存に追加」vs「すべて置き換え」の選択ダイアログを SettingsView に追加

### 優先度中（Watch 連携）

- [ ] **WatchConnectivity 実装** — iPhone から Watch へルーティンデータとタイマー状態を送信
- [ ] **Watch UI 実装** — 実行中タスク名・残り時間・進捗表示
- [ ] **Watch 操作** — 再生/一時停止・前後ジャンプを Watch から操作

### 優先度低

- [ ] **App Group 設定** — iPhone/Watch でデータストレージを共有（WatchConnectivity で代替可能な場合は不要）
- [ ] **アプリアイコン** — iOS / watchOS 用アイコン作成
- [ ] **バージョン管理** — `package.json` 相当の仕組みを検討
- [ ] **認証・デバイス間同期** — 現状は単体デバイスのみ。必要になったら検討
