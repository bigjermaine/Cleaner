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

    let cleaner = MergeConflictCleaner()
    
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
                    .border(Color.gray, width: 1)
                    .frame(minHeight: 150)
                    .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Resolution Strategy:")
                    .font(.headline)
                    .padding()
                
                Picker("Resolution Strategy", selection: $selectedResolution) {
                    Text("Keep HEAD (first option)").tag(MergeConflictCleaner.ConflictResolution.head)
                    Text("Keep Incoming (second option)").tag(MergeConflictCleaner.ConflictResolution.incoming)
                    Text("Remove All Conflicts").tag(MergeConflictCleaner.ConflictResolution.removeAll)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding()
            }
            
            Button("Clean Merge Conflicts") {
                cleanedContent = cleaner.clean(content: inputText, resolution: selectedResolution)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(inputText.isEmpty)
            
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .font(.caption)
                    }
                    
                    ScrollView {
                        Text(cleanedContent)
                            .font(.system(.body, design: .monospaced))
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
        .alert("Copied!", isPresented: $showingCopyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Cleaned content has been copied to clipboard")
        }
    }
}

#Preview {
    ContentView()
}
