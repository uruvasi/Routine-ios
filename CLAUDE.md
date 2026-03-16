# Routine-ios — CLAUDE.md

## プロジェクト概要

iPhone + Apple Watch 向けのネイティブアプリ（SwiftUI + watchOS）。
PWA版（routine-app）と Markdown 形式でデータ互換を持ちながら、バックグラウンドタイマー・Watch 通知・Watch UI を実現する。

PWA版リポジトリ: `uruvasi/routine-app`（別リポジトリ・独立して継続）

## スタック

- **Swift + SwiftUI**（iOS 26 / Xcode 26）
- **Swift Observation `@Observable`**（iOS 17+ / Combine 不使用）
- **watchOS** コンパニオンアプリ（`Routine-watch` ターゲット）
- **UserNotifications** — ローカル通知（Watch にもミラーリング）
- **AVFoundation** — TTS + `AVAudioEngine` プログラマティックトーン生成（消音モード対応）
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

- `TimerViewModel`（`@MainActor @Observable`）がタイマー状態を管理
- `taskEndDate: Date` 絶対時刻ベースで残り時間を計算（バックグラウンド復帰時に自動補正）
- タイマーは `RunLoop.main.add(t, forMode: .common)` で登録（スクロール中・バックグラウンド移行直後も発火）
- バックグラウンド移行時（`willBackground`）: 残り全タスクの通知を一括プレスケジュール・状態を UserDefaults に永続化
- フォアグラウンド復帰時（`didForeground`）: `taskEndDate` ベースで経過タスクを計算し状態を補正、通知を再スケジュール
- アプリ kill → 再起動時: 同一 routineId で保存済み状態があれば `init` で復元、`.onAppear` で `didForeground` を呼んで補正
- タスク完了時に `UNTimeIntervalNotificationTrigger` でローカル通知をスケジュール（Watch にもミラー）
- 音声: タスク開始時にビープ + TTS、完了時に別音（`AudioAlertManager`）
- 自動進行: 時間切れで次のタスクへ（`tick()` 内で処理）
- UserDefaults キー: `timer_taskIndex`、`timer_taskEndDate`、`timer_routineId`

## 音声仕様

- `AudioAlertManager.shared`（`@MainActor` シングルトン）
- `AVAudioSession.setCategory(.playback, .mixWithOthers)` — 消音スイッチを無視してバックグラウンド再生を許可
- トーン生成: `AVAudioEngine` + `AVAudioPlayerNode` でサイン波をプログラマティック生成（`AudioToolbox` 不使用）
  - 開始音: 880Hz / 0.12秒
  - 完了音: 660Hz / 0.35秒
- TTS: `AVSpeechSynthesizer` + `AVSpeechUtteranceDefaultSpeechRate` 基準の倍率（`SettingsStore.speechRate`）
  - `utterance.rate = Float(speechRate) * AVSpeechUtteranceDefaultSpeechRate`
  - `AVSpeechUtteranceDefaultSpeechRate = 0.5`（Apple 内部定数）
- `startSilentLoop()` / `stopSilentLoop()`: 無音ループで AVAudioSession を維持（`silentNode` 専用）

## 設定仕様（SettingsStore）

- `language: AppLanguage` — ja/en 切替（UserDefaults `appLanguage_v1`）
- `speechRate: Double` — TTS 速度倍率 1.0〜2.0（デフォルト 1.0、UserDefaults `speechRate_v1`）

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

**タイマー自動進行時に TTS が流れない**

`TimerViewModel.tick()` 内でタスクが時間切れ自動進行するとき、`lang` の参照がないため TTS がスキップされる。
手動の next/prev・start 時は正常に TTS が流れる。

**`DurationPickerSheet` の日本語ハードコード**

`RoutineEditorView` 内の `DurationPickerSheet` に `lang` が渡されていないため、英語モードでも「時間を設定」「完了」「キャンセル」と表示される。

**SourceKit の誤検知エラー**

`Shared/` フォルダが `fileSystemSynchronizedGroups` 経由でビルドに含まれているため、SourceKit（エディタ補完・診断）が `Routine`/`RoutineTask`/`AppLanguage` 等を「not found」と誤報告することがある。実際の Xcode ビルドは正常に通る。

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

### 2026-03-15 — セッション2: コードレビュー・バグ修正・@Observable 移行

1. **ビルドエラー解消**
   - `RoutineTimerView.swift` の `internal import SwiftUI` → `import SwiftUI`（`InternalImportsByDefault` 対応）
   - `TimerViewModel` の `var objectWillChange: ObservableObjectPublisher` 宣言を削除（`@Observable` が自動合成）
2. **バグ修正**
   - `SettingsView` のリセット処理 `routines.removeAll()` → `routineStore.resetAll()` に変更し `save()` が呼ばれるよう修正
   - `RoutineListView` の三項演算子の型不一致（`.secondary`/`.indigo`）を `Color.secondary`/`Color.indigo` に明示
   - `String(contentsOf:)` deprecation warning を `String(contentsOf:encoding:.utf8)` に修正
3. **`@Observable` 移行**（iOS 17+ / Combine 不使用）
   - `RoutineStore`、`SettingsStore`、`TimerViewModel`: `ObservableObject`+`@Published` → `@Observable`、`Combine` import 削除
   - 全 View: `@StateObject` → `@State`、`@EnvironmentObject` → `@Environment(Type.self)`、`.environmentObject()` → `.environment()`
4. **`project.pbxproj` 修正**
   - 存在しない `Models.swift`/`RoutineStore.swift` への stray 参照を4箇所から削除
   - `Shared/` フォルダを `PBXFileSystemSynchronizedRootGroup` として登録し、`Routine-ios` ターゲットのコンパイル対象に追加

**現在の状態:** ビルド成功・Warning 0件。`@Observable` ベースのモダンな実装に刷新済み。Watch はプレースホルダーのみ。

---

### 2026-03-15 — セッション3: 音声・バックグラウンド・設定強化

1. **消音モード対応**
   - `AudioToolbox` の `AudioServicesPlaySystemSound` を廃止
   - `AVAudioEngine` + `AVAudioPlayerNode` でサイン波トーンをプログラマティック生成
   - `AVAudioSession.setCategory(.playback, .mixWithOthers)` で消音スイッチを無視
2. **バックグラウンドタイマー修正**
   - `Timer.scheduledTimer` → `RunLoop.main.add(t, forMode: .common)` に変更（スクロール中も発火）
   - `willBackground` / `didForeground` を実装（`scenePhase` に連動）
   - `taskEndDate` 絶対時刻ベースで経過タスクを補正（`didForeground` でループ fast-forward）
   - UserDefaults に `taskIndex`・`taskEndDate`・`routineId` を永続化（kill 復帰対応）
   - バックグラウンド中は残り全タスクの通知を一括プレスケジュール（`willBackground`）
3. **TTS 速度設定**
   - `SettingsStore.speechRate: Double`（1.0〜2.0、UserDefaults `speechRate_v1`）
   - `SettingsView` にスライダー追加（step 0.1、1.0x〜2.0x 表示）
   - `AudioAlertManager.speechRate` を `RoutineTimerView.onAppear` で同期
   - `utterance.rate = Float(speechRate) * AVSpeechUtteranceDefaultSpeechRate`（`DefaultSpeechRate = 0.5`）
4. **バージョン表示**
   - `SettingsView` の最下部にアプリバージョン + ビルド番号を表示
   - `project.pbxproj` にシェルスクリプトフェーズ追加: git commit 数をビルド番号に自動設定
5. **`TESTING.md` 作成**
   - 実機テスト手順（Developer Mode 設定・証明書信頼・チェックリスト）
6. **バグ修正（セッション2 未対応分）**
   - `RoutineStore.resetAll()` 追加（`routines.removeAll()` が `save()` を呼ばない問題）
   - `String(contentsOf:)` deprecation → `encoding: .utf8`
   - `SettingsView.body` type-check タイムアウト → `languageSection` / `speechRateSection` に分割
   - Slider binding のため `@Bindable var settings = settingsStore` を body 内で使用

**現在の状態:** 消音モード対応・バックグラウンドタイマー・TTS 速度設定・バージョン表示が実装済み。実機動作確認済み。

---

### 2026-03-15 — セッション4: バグ修正・機能完成

1. **タイマー自動進行 TTS 修正**
   - `TimerViewModel` に `private var lang: AppLanguage = .ja` を追加
   - `start(lang:)` / `didForeground(lang:)` で `self.lang` に保存
   - `tick()` 内の自動進行時に完了音 + 次タスク名の TTS を追加
   - 次タスクの通知も `tick()` 内でスケジュール
   - 最終タスク完了時は `finish(lang: lang)` を呼ぶよう統一（重複コード削除）
2. **ビルドサンドボックスエラー修正**
   - `ENABLE_USER_SCRIPT_SANDBOXING = YES` → `NO`（Debug・Release 両設定）
   - git + PlistBuddy がビルドスクリプト内でファイルアクセスできるよう修正
3. **TTS 速度スライダー表示修正**
   - 内部値 0.5〜1.0 を表示上 1.0x〜2.0x に変換（`speechRate * 2.0`）
4. **Import モード選択 UI**
   - `@State private var pendingImportText: String?` を追加
   - ファイル選択後に `confirmationDialog` で「既存に追加」/「すべて置き換え」を選択
   - `RoutineStore.importMarkdown(_:replace:)` の既存 API をそのまま利用
5. **DurationPickerSheet i18n**
   - `lang: AppLanguage` パラメータを追加
   - 「時間を設定」→ `l.setDuration`（en: "Set Duration"）を `Localization.swift` に追加
   - 「完了」「キャンセル」→ `l.done` / `l.cancel`
   - ピッカーの「分」「秒」→ `l.minutes` / `l.seconds`（en: "min" / "sec"）

**現在の状態:** 優先度高バックログ3件がすべて完了。Watch 連携以外の iPhone 機能は実装済み。

---

## バックログ

### 優先度高（次のセッションでやること）
- [ ] イヤホン接続時に聞こえない？ Airpod 片耳だとなんか聞こえなかったが両耳だと大丈夫かも
- [ ] iPhoneバックグラウンド処理で甘いところがありそう 朝1のタスクが昼まで残ってた。要チェック
- [ ] そもそもタスク始めた後で、どのタスクが動いているのか分からない？　もしかして複数同時に動いてたりしないか　別の画面に遷移したときに進捗状況が分かるようにしたいな

### 優先度中（Watch 連携）

- [ ] **WatchConnectivity 実装** — iPhone から Watch へルーティンデータとタイマー状態を送信
- [ ] **Watch UI 実装** — 実行中タスク名・残り時間・進捗表示
- [ ] **Watch 操作** — 再生/一時停止・前後ジャンプを Watch から操作

### 優先度低

- [ ] **App Group 設定** — iPhone/Watch でデータストレージを共有（WatchConnectivity で代替可能な場合は不要）
- [ ] **アプリアイコン** — iOS / watchOS 用アイコン作成
- [ ] **バージョン管理** — `package.json` 相当の仕組みを検討
- [ ] **認証・デバイス間同期** — 現状は単体デバイスのみ。必要になったら検討
