//
//  SettingsView.swift
//  Routine-ios
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(RoutineStore.self) var routineStore
    @Environment(SettingsStore.self) var settingsStore

    @State private var showImportSheet = false
    @State private var showResetConfirm = false
    @State private var exportDocument: MarkdownFile?
    @State private var pendingImportText: String?

    private var l: L { settingsStore.l }

    var body: some View {
        @Bindable var settings = settingsStore
        Form {
            languageSection
            speechRateSection(settings: $settings)


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

            Section {
                HStack {
                    Spacer()
                    Text("Version \(appVersion)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
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
                routineStore.resetAll()
            }
            Button(l.cancel, role: .cancel) {}
        }
        .confirmationDialog(l.importMarkdown, isPresented: Binding(
            get: { pendingImportText != nil },
            set: { if !$0 { pendingImportText = nil } }
        ), titleVisibility: .visible) {
            Button(l.appendImport) {
                if let text = pendingImportText {
                    routineStore.importMarkdown(text, replace: false)
                    pendingImportText = nil
                }
            }
            Button(l.replaceImport, role: .destructive) {
                if let text = pendingImportText {
                    routineStore.importMarkdown(text, replace: true)
                    pendingImportText = nil
                }
            }
            Button(l.cancel, role: .cancel) { pendingImportText = nil }
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result,
              let url = urls.first,
              url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        pendingImportText = text
    }

    @ViewBuilder
    private var languageSection: some View {
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
    }

    @ViewBuilder
    private func speechRateSection(settings: Bindable<SettingsStore>) -> some View {
        Section(l.speechRateSection) {
            VStack(spacing: 8) {
                HStack {
                    Text(l.speechRateSlow).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1fx", settingsStore.speechRate * 2.0))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.indigo)
                    Spacer()
                    Text(l.speechRateFast).font(.caption).foregroundStyle(.secondary)
                }
                Slider(value: settings.speechRate, in: 0.5...1.0, step: 0.1)
                    .tint(.indigo)
                    .padding(.vertical, 8)
            }
            .padding(.vertical, 4)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
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
