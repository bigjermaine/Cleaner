//
//  ContentView.swift
//  Cleaner
//
//  Created by Daniel Jermaine on 05/07/2025.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var inputText = ""
    @State private var cleanedContent = ""
    @State private var showingCopyAlert = false
    @State private var selectedResolution: MergeConflictCleaner.ConflictResolution = .head
    @State private var isCleaning = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var selectedFileURL: URL?
    @State private var showingOverwriteConfirmation = false
    @State private var securityScopedURL: URL?

    private let cleaner = MergeConflictCleaner()

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sourcePane

                    if let errorMessage {
                        statusRow(message: errorMessage,
                                  icon: "exclamationmark.triangle.fill",
                                  color: .red)
                    }

                    if let successMessage {
                        statusRow(message: successMessage,
                                  icon: "checkmark.circle.fill",
                                  color: .green)
                    }

                    if !cleanedContent.isEmpty {
                        outputPane
                    }
                }
                .padding(20)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 620, minHeight: 560)
        .alert("Copied!", isPresented: $showingCopyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Cleaned content has been copied to clipboard")
        }
        .confirmationDialog(
            "Overwrite the selected file?",
            isPresented: $showingOverwriteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clean and Overwrite File", role: .destructive) {
                Task { await cleanConflicts(overwriteFile: true) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Cleaner will replace the file’s current contents. This cannot be undone by the app.")
        }
        .onDisappear {
            stopAccessingSelectedFile()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "swift")
                .foregroundStyle(.orange)
            Text("Merge Conflict Cleaner")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            Picker("", selection: $selectedResolution) {
                ForEach(MergeConflictCleaner.ConflictResolution.allCases) { strategy in
                    Text(strategy.title).tag(strategy)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 300)
            .disabled(isCleaning)

            Button {
                if selectedFileURL == nil {
                    Task { await cleanConflicts(overwriteFile: false) }
                } else {
                    showingOverwriteConfirmation = true
                }
            } label: {
                HStack(spacing: 6) {
                    if isCleaning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(isCleaning ? "Cleaning" : "Clean")
                }
                .frame(minWidth: 72)
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.isEmpty || isCleaning || smartUnavailable)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Source

    private var sourcePane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(selectedFileURL == nil ? "Source" : "Source · file")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button("Choose File…") {
                    chooseFile()
                }
                .buttonStyle(.link)
                .disabled(isCleaning)
            }

            if let selectedFileURL {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.secondary)
                    Text(selectedFileURL.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(selectedFileURL.path)

                    Spacer()

                    Button {
                        clearSelectedFile()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Use pasted text instead")
                }
                .font(.system(size: 11, design: .monospaced))
            }

            codePanel {
                TextEditor(text: $inputText)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 200)
            }

            if selectedResolution == .smart, let message = cleaner.smartAvailabilityMessage {
                statusRow(message: message,
                          icon: "sparkles",
                          color: .orange)
            }
        }
    }

    // MARK: - Output

    private var outputPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Result")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cleanedContent, forType: .string)
                    showingCopyAlert = true
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            codePanel {
                ScrollView {
                    Text(cleanedContent)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
            }
        }
    }

    // MARK: - Building blocks

    private func codePanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }

    private func statusRow(message: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(message)
        }
        .font(.system(size: 11))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var smartUnavailable: Bool {
        selectedResolution == .smart && !cleaner.isSmartAvailable
    }

    @MainActor
    private func cleanConflicts(overwriteFile: Bool) async {
        errorMessage = nil
        successMessage = nil
        isCleaning = true
        defer { isCleaning = false }

        do {
            let cleaned = try await cleaner.clean(
                content: inputText,
                resolution: selectedResolution
            )

            if overwriteFile, let selectedFileURL {
                try cleaned.write(to: selectedFileURL, atomically: true, encoding: .utf8)
                inputText = cleaned
                successMessage = "Cleaned and saved \(selectedFileURL.lastPathComponent)."
            }

            cleanedContent = cleaned
        } catch {
            cleanedContent = ""
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Swift file with merge conflicts"
        panel.prompt = "Choose"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.swiftSource]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        loadFile(from: url)
    }

    @MainActor
    private func loadFile(from url: URL) {
        stopAccessingSelectedFile()
        let startedSecurityScopedAccess = url.startAccessingSecurityScopedResource()

        do {
            inputText = try String(contentsOf: url, encoding: .utf8)
            selectedFileURL = url
            securityScopedURL = startedSecurityScopedAccess ? url : nil
            cleanedContent = ""
            errorMessage = nil
            successMessage = nil
        } catch {
            if startedSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
            selectedFileURL = nil
            errorMessage = "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    @MainActor
    private func clearSelectedFile() {
        stopAccessingSelectedFile()
        selectedFileURL = nil
        successMessage = nil
    }

    @MainActor
    private func stopAccessingSelectedFile() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }
}

#Preview {
    ContentView()
}
