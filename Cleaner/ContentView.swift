//
//  ContentView.swift
//  Cleaner
//
//  Created by Daniel Jermaine on 05/07/2025.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var inputText = ""
    @State private var cleanedContent = ""
    @State private var showingCopyAlert = false
    @State private var selectedResolution: MergeConflictCleaner.ConflictResolution = .head
    @State private var isCleaning = false
    @State private var errorMessage: String?

    private let cleaner = MergeConflictCleaner()

    var body: some View {
        VStack(spacing: 20) {
            Text("Merge Conflict Cleaner")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()

            VStack(alignment: .leading, spacing: 10) {
                Text("Paste your text with merge conflicts:")
                    .font(.headline)

                TextEditor(text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.gray, width: 1)
                    .frame(minHeight: 150)
                    .padding(.horizontal)
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
                Task { await cleanConflicts() }
            } label: {
                HStack(spacing: 8) {
                    if isCleaning {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isCleaning ? "Cleaning…" : "Clean Merge Conflicts")
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
    }

    private var smartUnavailable: Bool {
        selectedResolution == .smart && !cleaner.isSmartAvailable
    }

    @MainActor
    private func cleanConflicts() async {
        errorMessage = nil
        isCleaning = true
        defer { isCleaning = false }

        do {
            cleanedContent = try await cleaner.clean(
                content: inputText,
                resolution: selectedResolution
            )
        } catch {
            cleanedContent = ""
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
