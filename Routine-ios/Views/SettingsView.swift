//
//  SettingsView.swift
//  Routine-ios
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var routineStore: RoutineStore
    @EnvironmentObject var settingsStore: SettingsStore

    @State private var showImportSheet = false
    @State private var showResetConfirm = false
    @State private var exportDocument: MarkdownFile?

    private var l: L { settingsStore.l }

    var body: some View {
        Form {
            // Language
            Section(l.languageSection) {
                HStack {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Button {
                            settingsStore.language = lang
                        } label: {
                            Text(lang == .ja ? l.japanese : l.english)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(settingsStore.language == lang ? Color.indigo : Color.clear)
                                .foregroundStyle(settingsStore.language == lang ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Data
            Section(l.dataSection) {
                Button {
                    let text = routineStore.exportMarkdown()
                    exportDocument = MarkdownFile(text: text)
                } label: {
                    Label(l.exportMarkdown, systemImage: "square.and.arrow.up")
                }

                Button {
                    showImportSheet = true
                } label: {
                    Label(l.importMarkdown, systemImage: "square.and.arrow.down")
                }
            }

            Section {
                Button(l.resetAllData, role: .destructive) {
                    showResetConfirm = true
                }
            }
        }
        .navigationTitle(l.settingsTitle)
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { if !$0 { exportDocument = nil } }
            ),
            document: exportDocument ?? MarkdownFile(text: ""),
            contentType: .plainText,
            defaultFilename: "routines-\(todayString()).md"
        ) { _ in
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showImportSheet,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .confirmationDialog(l.confirmReset, isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button(l.resetAllData, role: .destructive) {
                routineStore.routines.removeAll()
            }
            Button(l.cancel, role: .cancel) {}
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result,
              let url = urls.first,
              url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let text = try? String(contentsOf: url) else { return }

        // Show action sheet to choose append or replace
        // For simplicity, using confirmationDialog
        routineStore.importMarkdown(text, replace: false)
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Exportable document

struct MarkdownFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String

    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
