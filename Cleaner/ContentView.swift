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
    @State private var isDropTargeted = false
    @State private var securityScopedURL: URL?

    private let cleaner = MergeConflictCleaner()

    var body: some View {
        VStack(spacing: 20) {
            Text("Merge Conflict Cleaner")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(selectedFileURL == nil
                         ? "Paste your text with merge conflicts:"
                         : "Selected file:")
                        .font(.headline)

                    Spacer()

                    Button("Choose File…") {
                        chooseFile()
                    }
                    .disabled(isCleaning)
                }
                .padding(.horizontal)

                if let selectedFileURL {
                    HStack {
                        Image(systemName: "doc")
                        Text(selectedFileURL.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(selectedFileURL.path)

                        Spacer()

                        Button {
                            clearSelectedFile()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .help("Use pasted text instead")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                }

                ZStack {
                    DropThroughTextEditor(text: $inputText)
                        .opacity(isDropTargeted ? 0.35 : 1)

                    if isDropTargeted {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.largeTitle)
                            Text("Drop Swift file to load")
                                .font(.headline)
                        }
                        .foregroundStyle(.tint)
                        .allowsHitTesting(false)
                    } else if inputText.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "doc.badge.plus")
                                .font(.title2)
                            Text("Drop a Swift file here")
                                .font(.callout)
                        }
                        .foregroundStyle(.secondary)
                        .allowsHitTesting(false)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isDropTargeted ? Color.accentColor : Color.gray,
                            style: StrokeStyle(
                                lineWidth: isDropTargeted ? 2 : 1,
                                dash: isDropTargeted ? [7] : []
                            )
                        )
                }
                .frame(minHeight: 150)
                .padding(.horizontal)
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleDrop(providers: providers)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Resolution Strategy:")
                    .font(.headline)
                    .padding(.horizontal)

                Picker("Resolution Strategy", selection: $selectedResolution) {
                    ForEach(MergeConflictCleaner.ConflictResolution.allCases) { strategy in
                        Text(strategy.title).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .disabled(isCleaning)

                if selectedResolution == .smart {
                    Text(cleaner.smartAvailabilityMessage
                         ?? "Uses on-device Apple Intelligence to choose the best resolution.")
                        .font(.caption)
                        .foregroundColor(cleaner.isSmartAvailable ? .secondary : .primary)
                        .padding(.horizontal)
                }
            }

            Button {
                if selectedFileURL == nil {
                    Task { await cleanConflicts(overwriteFile: false) }
                } else {
                    showingOverwriteConfirmation = true
                }
            } label: {
                HStack(spacing: 8) {
                    if isCleaning {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isCleaning
                         ? "Cleaning…"
                         : selectedFileURL == nil
                            ? "Clean Merge Conflicts"
                            : "Clean Selected File")
                }
                .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.isEmpty || isCleaning || smartUnavailable)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            if let successMessage {
                Text(successMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal)
            }

            if !cleanedContent.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Cleaned Content:")
                            .font(.headline)

                        Spacer()

                        Button("Copy to Clipboard") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(cleanedContent, forType: .string)
                            showingCopyAlert = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }

                    ScrollView {
                        Text(cleanedContent)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 300)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 560, minHeight: 520)
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

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let itemURL = item as? URL {
                url = itemURL
            } else {
                url = nil
            }

            DispatchQueue.main.async {
                guard let url, !url.hasDirectoryPath,
                      url.pathExtension.lowercased() == "swift" else {
                    errorMessage = "Drop a Swift source file with the .swift extension."
                    return
                }
                loadFile(from: url)
            }
        }

        return true
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

/// A plain-text editor that opts out of AppKit drag handling so file drops
/// reach the surrounding SwiftUI `onDrop` modifier. A regular `TextEditor`'s
/// underlying `NSTextView` intercepts file drags and inserts the path as text.
private struct DropThroughTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.unregisterDraggedTypes()

        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

#Preview {
    ContentView()
}
