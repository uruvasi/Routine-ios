import Foundation

struct L {
    let lang: AppLanguage

    // Tabs
    var routinesTab: String { lang == .ja ? "ルーティン" : "Routines" }
    var settingsTab: String  { lang == .ja ? "設定" : "Settings" }

    // List
    var noRoutines: String   { lang == .ja ? "ルーティンがありません" : "No routines" }
    var run: String          { lang == .ja ? "実行" : "Run" }
    var editButton: String   { lang == .ja ? "編集" : "Edit" }
    var done: String         { lang == .ja ? "完了" : "Done" }
    var delete: String       { lang == .ja ? "削除" : "Delete" }
    var tasks: String        { lang == .ja ? "タスク" : "tasks" }
    var total: String        { lang == .ja ? "合計" : "Total" }

    // Editor
    var newRoutine: String           { lang == .ja ? "新規ルーティン" : "New Routine" }
    var editRoutine: String          { lang == .ja ? "ルーティン編集" : "Edit Routine" }
    var routineNamePlaceholder: String { lang == .ja ? "ルーティン名" : "Routine name" }
    var tasks2: String               { lang == .ja ? "タスク" : "Tasks" }
    var addTask: String              { lang == .ja ? "タスクを追加" : "Add task" }
    var taskNamePlaceholder: String  { lang == .ja ? "タスク名" : "Task name" }
    var minutes: String              { lang == .ja ? "分" : "min" }
    var seconds: String              { lang == .ja ? "秒" : "sec" }
    var deleteRoutine: String        { lang == .ja ? "ルーティンを削除" : "Delete Routine" }
    var confirmDeleteRoutine: String { lang == .ja ? "このルーティンを削除しますか？" : "Delete this routine?" }
    var cancel: String               { lang == .ja ? "キャンセル" : "Cancel" }
    var yes: String                  { lang == .ja ? "はい" : "Yes" }

    // Timer
    var start: String          { lang == .ja ? "開始" : "Start" }
    var pause: String          { lang == .ja ? "一時停止" : "Pause" }
    var resume: String         { lang == .ja ? "再開" : "Resume" }
    var finished: String       { lang == .ja ? "完了！" : "Finished!" }
    var finishedBody: String   { lang == .ja ? "すべてのタスクが終わりました" : "All tasks completed" }
    var backToList: String     { lang == .ja ? "一覧に戻る" : "Back to list" }

    // Settings
    var settingsTitle: String  { lang == .ja ? "設定" : "Settings" }
    var languageSection: String { lang == .ja ? "言語" : "Language" }
    var japanese: String       { "日本語" }
    var english: String        { "English" }
    var dataSection: String    { lang == .ja ? "データ" : "Data" }
    var exportMarkdown: String { lang == .ja ? "Markdownでエクスポート" : "Export as Markdown" }
    var importMarkdown: String { lang == .ja ? "Markdownをインポート" : "Import Markdown" }
    var appendImport: String   { lang == .ja ? "既存に追加" : "Append" }
    var replaceImport: String  { lang == .ja ? "すべて置き換え" : "Replace All" }
    var resetAllData: String   { lang == .ja ? "すべてリセット" : "Reset All" }
    var confirmReset: String   { lang == .ja ? "すべてのルーティンを削除しますか？" : "Delete all routines?" }

    // TTS
    func speakTaskStart(_ name: String) -> String {
        lang == .ja ? "\(name)をはじめます" : "Starting \(name)"
    }
    func speakFinished() -> String {
        lang == .ja ? "すべてのタスクが完了しました" : "All tasks completed"
    }
}
