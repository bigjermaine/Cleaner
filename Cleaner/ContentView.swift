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
    @State private var isDropTargeted = false

    private let cleaner = MergeConflictCleaner()

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()
                .opacity(0.6)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
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
        .background {
            ZStack {
                VisualEffectBackground(material: .underWindowBackground)
                MergeBackdrop()
            }
            .ignoresSafeArea()
        }
        .frame(minWidth: 660, minHeight: 580)
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
        .padding(.vertical, 12)
        .background(
            VisualEffectBackground(material: .headerView)
        )
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

            codePanel(isHighlighted: isDropTargeted) {
                ZStack {
                    DropThroughTextEditor(
                        text: $inputText,
                        isDropTargeted: $isDropTargeted,
                        onDropFile: { url in
                            guard !url.hasDirectoryPath,
                                  url.pathExtension.lowercased() == "swift" else {
                                errorMessage = "Drop a Swift source file with the .swift extension."
                                return
                            }
                            loadFile(from: url)
                        }
                    )
                    .frame(minHeight: 200)

                    if isDropTargeted {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.title)
                            Text("Drop Swift file")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.tint)
                        .allowsHitTesting(false)
                    } else if inputText.isEmpty {
                        Text("Paste conflicted code, or drop a .swift file here")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .allowsHitTesting(false)
                    }
                }
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

    private func codePanel<Content: View>(
        isHighlighted: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(Color(nsColor: .textBackgroundColor).opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isHighlighted ? Color.accentColor : Color.primary.opacity(0.08),
                        style: StrokeStyle(lineWidth: isHighlighted ? 2 : 1,
                                           dash: isHighlighted ? [6] : [])
                    )
            )
            .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
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
        inputText = ""
        cleanedContent = ""
        successMessage = nil
        errorMessage = nil
    }

    @MainActor
    private func stopAccessingSelectedFile() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }
}

/// Text editor that accepts Finder file drops over its full bounds.
/// SwiftUI `onDrop` only receives hits on padding around an `NSViewRepresentable`,
/// so file loading is handled here in AppKit instead.
private struct DropThroughTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isDropTargeted: Bool
    var onDropFile: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isDropTargeted: $isDropTargeted, onDropFile: onDropFile)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        let textView = FileDropTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.onDropTargeted = { targeted in
            DispatchQueue.main.async {
                context.coordinator.isDropTargeted.wrappedValue = targeted
            }
        }
        textView.onDropFile = { url in
            DispatchQueue.main.async {
                context.coordinator.onDropFile(url)
            }
        }

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.isDropTargeted = $isDropTargeted
        context.coordinator.onDropFile = onDropFile

        guard let textView = scrollView.documentView as? FileDropTextView else { return }
        textView.onDropFile = { url in
            DispatchQueue.main.async {
                context.coordinator.onDropFile(url)
            }
        }
        textView.onDropTargeted = { targeted in
            DispatchQueue.main.async {
                context.coordinator.isDropTargeted.wrappedValue = targeted
            }
        }
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var isDropTargeted: Binding<Bool>
        var onDropFile: (URL) -> Void

        init(text: Binding<String>,
             isDropTargeted: Binding<Bool>,
             onDropFile: @escaping (URL) -> Void) {
            self.text = text
            self.isDropTargeted = isDropTargeted
            self.onDropFile = onDropFile
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

private final class FileDropTextView: NSTextView {
    var onDropFile: ((URL) -> Void)?
    var onDropTargeted: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    private func fileURL(from info: NSDraggingInfo) -> URL? {
        let pasteboard = info.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return nil
        }
        return urls.first
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard fileURL(from: sender) != nil else {
            return super.draggingEntered(sender)
        }
        onDropTargeted?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard fileURL(from: sender) != nil else {
            return super.draggingUpdated(sender)
        }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDropTargeted?(false)
        super.draggingExited(sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        fileURL(from: sender) != nil || super.prepareForDragOperation(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDropTargeted?(false)
        if let url = fileURL(from: sender) {
            onDropFile?(url)
            return true
        }
        return super.performDragOperation(sender)
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onDropTargeted?(false)
        super.concludeDragOperation(sender)
    }
}

/// Decorative backdrop that illustrates what the app does: two conflicting
/// branches converging into a single resolved trunk, annotated with the Git
/// conflict markers the cleaner removes.
private struct MergeBackdrop: View {
    private let headColor = Color.blue
    private let incomingColor = Color.orange
    private let resolvedColor = Color.green

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let mergeX = width * 0.5
            let mergeY = height * 0.52
            let trunkEndY = height * 0.94

            ZStack {
                branch(
                    from: CGPoint(x: width * 0.16, y: height * 0.08),
                    to: CGPoint(x: mergeX, y: mergeY),
                    color: headColor
                )

                branch(
                    from: CGPoint(x: width * 0.84, y: height * 0.08),
                    to: CGPoint(x: mergeX, y: mergeY),
                    color: incomingColor
                )

                Path { path in
                    path.move(to: CGPoint(x: mergeX, y: mergeY))
                    path.addLine(to: CGPoint(x: mergeX, y: trunkEndY))
                }
                .stroke(resolvedColor.opacity(0.22), style: StrokeStyle(lineWidth: 5, lineCap: .round))

                commitDot(at: CGPoint(x: width * 0.16, y: height * 0.08), color: headColor)
                commitDot(at: CGPoint(x: width * 0.84, y: height * 0.08), color: incomingColor)
                commitDot(at: CGPoint(x: mergeX, y: mergeY), color: resolvedColor, radius: 9)
                commitDot(at: CGPoint(x: mergeX, y: trunkEndY), color: resolvedColor)

                marker("<<<<<<< HEAD", color: headColor)
                    .position(x: width * 0.16, y: height * 0.08 - 20)

                marker(">>>>>>> incoming", color: incomingColor)
                    .position(x: width * 0.84, y: height * 0.08 - 20)

                marker("=======", color: .secondary)
                    .position(x: mergeX, y: mergeY - 22)

                marker("resolved", color: resolvedColor)
                    .position(x: mergeX, y: trunkEndY + 18)
            }
        }
        .allowsHitTesting(false)
    }

    private func branch(from start: CGPoint, to end: CGPoint, color: Color) -> some View {
        Path { path in
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x, y: (start.y + end.y) / 2),
                control2: CGPoint(x: end.x, y: start.y + (end.y - start.y) * 0.35)
            )
        }
        .stroke(color.opacity(0.22), style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }

    private func commitDot(at point: CGPoint, color: Color, radius: CGFloat = 7) -> some View {
        Circle()
            .fill(color.opacity(0.28))
            .frame(width: radius * 2, height: radius * 2)
            .position(point)
    }

    private func marker(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(color.opacity(0.35))
    }
}

/// Bridges `NSVisualEffectView` so the window picks up native macOS vibrancy
/// instead of a flat fill.
private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

#Preview {
    ContentView()
}
