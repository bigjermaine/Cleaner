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
        ScrollView {
            VStack(spacing: 24) {
                header
                inputCard
                strategyCard
                cleanButton

                if let errorMessage {
                    banner(message: errorMessage, icon: "exclamationmark.triangle.fill", color: .red)
                }

                if let successMessage {
                    banner(message: successMessage, icon: "checkmark.seal.fill", color: .green)
                }

                if !cleanedContent.isEmpty {
                    resultCard
                }
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.12),
                    Color.purple.opacity(0.10),
                    Color.pink.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
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

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple],
                                       startPoint: .top, endPoint: .bottom)
                    )

                Text("Merge Conflict Cleaner")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .purple, .pink],
                                       startPoint: .leading, endPoint: .trailing)
                    )
            }

            Text("Resolve Git conflict markers in seconds")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(selectedFileURL == nil ? "Paste conflicted text" : "Selected file",
                      systemImage: selectedFileURL == nil ? "doc.on.clipboard" : "doc.text")
                    .font(.headline)
                    .foregroundStyle(.blue)

                Spacer()

                Button {
                    chooseFile()
                } label: {
                    Label("Choose File…", systemImage: "folder.fill")
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .disabled(isCleaning)
            }

            if let selectedFileURL {
                HStack {
                    Image(systemName: "swift")
                        .foregroundStyle(.orange)
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
                .font(.caption)
                .padding(8)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            TextEditor(text: $inputText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 150)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            LinearGradient(colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                )
        }
        .padding(16)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .blue.opacity(0.08), radius: 8, y: 4)
    }

    private var strategyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Resolution Strategy", systemImage: "arrow.triangle.branch")
                .font(.headline)
                .foregroundStyle(.purple)

            HStack(spacing: 10) {
                ForEach(MergeConflictCleaner.ConflictResolution.allCases) { strategy in
                    strategyButton(strategy)
                }
            }

            if selectedResolution == .smart {
                Label(
                    cleaner.smartAvailabilityMessage
                        ?? "Uses on-device Apple Intelligence to choose the best resolution.",
                    systemImage: cleaner.isSmartAvailable ? "sparkles" : "exclamationmark.circle"
                )
                .font(.caption)
                .foregroundStyle(cleaner.isSmartAvailable ? Color.secondary : Color.orange)
            }
        }
        .padding(16)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .purple.opacity(0.08), radius: 8, y: 4)
    }

    private func strategyButton(_ strategy: MergeConflictCleaner.ConflictResolution) -> some View {
        let isSelected = selectedResolution == strategy

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedResolution = strategy
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: strategy.iconName)
                    .font(.title3)
                Text(strategy.title)
                    .font(.subheadline.weight(.semibold))
                Text(strategy.subtitle)
                    .font(.caption2)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? Color.white : strategy.accentColor)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                          ? AnyShapeStyle(strategy.accentColor.gradient)
                          : AnyShapeStyle(strategy.accentColor.opacity(0.12)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(strategy.accentColor.opacity(isSelected ? 0 : 0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isCleaning)
    }

    private var cleanButton: some View {
        Button {
            if selectedFileURL == nil {
                Task { await cleanConflicts(overwriteFile: false) }
            } else {
                showingOverwriteConfirmation = true
            }
        } label: {
            HStack(spacing: 10) {
                if isCleaning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isCleaning
                     ? "Cleaning…"
                     : selectedFileURL == nil
                        ? "Clean Merge Conflicts"
                        : "Clean Selected File")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(minWidth: 240)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [.blue, .purple],
                                   startPoint: .leading, endPoint: .trailing)
                )
            )
            .shadow(color: .purple.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(inputText.isEmpty || isCleaning || smartUnavailable)
        .opacity(inputText.isEmpty || smartUnavailable ? 0.5 : 1)
    }

    private func banner(message: String, icon: String, color: Color) -> some View {
        Label(message, systemImage: icon)
            .font(.callout)
            .foregroundStyle(color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Cleaned Content", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cleanedContent, forType: .string)
                    showingCopyAlert = true
                } label: {
                    Label("Copy", systemImage: "doc.on.doc.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            ScrollView {
                Text(cleanedContent)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 300)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.green.opacity(0.4), lineWidth: 1.5)
            )
        }
        .padding(16)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .green.opacity(0.1), radius: 8, y: 4)
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

private extension MergeConflictCleaner.ConflictResolution {
    var iconName: String {
        switch self {
        case .head: return "arrow.up.doc.fill"
        case .incoming: return "arrow.down.doc.fill"
        case .removeAll: return "trash.fill"
        case .smart: return "sparkles"
        }
    }

    var subtitle: String {
        switch self {
        case .head: return "Keep first side"
        case .incoming: return "Keep second side"
        case .removeAll: return "Drop both sides"
        case .smart: return "Apple Intelligence"
        }
    }

    var accentColor: Color {
        switch self {
        case .head: return .blue
        case .incoming: return .teal
        case .removeAll: return .red
        case .smart: return .purple
        }
    }
}

#Preview {
    ContentView()
}
