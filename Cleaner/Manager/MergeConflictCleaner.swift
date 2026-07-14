//
//  MergeConflictCleaner.swift
//  Cleaner
//
//  Created by Daniel Jermaine on 05/07/2025.
//

import Foundation
import FoundationModels

class MergeConflictCleaner {

    enum ConflictResolution: String, CaseIterable, Identifiable {
        case head
        case incoming
        case removeAll
        case smart

        var id: String { rawValue }

        var title: String {
            switch self {
            case .head: return "HEAD"
            case .incoming: return "Incoming"
            case .removeAll: return "Remove"
            case .smart: return "Smart"
            }
        }
    }

    enum CleanerError: LocalizedError {
        case modelUnavailable(String)
        case emptyResponse
        case markersRemain

        var errorDescription: String? {
            switch self {
            case .modelUnavailable(let reason):
                return reason
            case .emptyResponse:
                return "Apple Intelligence returned an empty result."
            case .markersRemain:
                return "Smart clean still contained conflict markers. Try again or use a rule-based strategy."
            }
        }
    }

    private let model = SystemLanguageModel.default

    var isSmartAvailable: Bool {
        model.isAvailable
    }

    var smartAvailabilityMessage: String? {
        switch model.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This Mac doesn’t support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in System Settings to use Smart resolution."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still downloading or preparing. Try again shortly."
        case .unavailable:
            return "Apple Intelligence isn’t available right now."
        }
    }

    func clean(content: String, resolution: ConflictResolution = .head) async throws -> String {
        switch resolution {
        case .smart:
            return try await smartClean(content: content)
        case .head, .incoming, .removeAll:
            return cleanMechanically(content: content, resolution: resolution)
        }
    }

    func cleanMechanically(content: String, resolution: ConflictResolution) -> String {
        var result = ""
        var conflictDepth = 0
        var inHeadSection = false
        var inIncomingSection = false

        for line in content.components(separatedBy: .newlines) {
            if line.hasPrefix("<<<<<<<") {
                conflictDepth += 1
                inHeadSection = true
                inIncomingSection = false
                continue
            } else if line.hasPrefix("=======") && conflictDepth > 0 {
                inHeadSection = false
                inIncomingSection = true
                continue
            } else if line.hasPrefix(">>>>>>>") {
                conflictDepth = max(0, conflictDepth - 1)
                inHeadSection = false
                inIncomingSection = false
                continue
            }

            let shouldIncludeLine: Bool

            if conflictDepth == 0 {
                shouldIncludeLine = true
            } else {
                switch resolution {
                case .head:
                    shouldIncludeLine = inHeadSection
                case .incoming:
                    shouldIncludeLine = inIncomingSection
                case .removeAll, .smart:
                    shouldIncludeLine = false
                }
            }

            if shouldIncludeLine {
                result += line + "\n"
            }
        }

        return result
    }

    private func smartClean(content: String) async throws -> String {
        guard model.isAvailable else {
            throw CleanerError.modelUnavailable(
                smartAvailabilityMessage ?? "Apple Intelligence isn’t available."
            )
        }

        let conflicts = extractTopLevelConflicts(from: content)
        if conflicts.isEmpty {
            return content
        }

        // Resolve conflicts one at a time to stay within the on-device context window.
        if conflicts.count > 1 || content.count > 6_000 {
            return try await smartCleanByConflict(content: content, conflicts: conflicts)
        }

        return try await smartCleanWholeFile(content: content)
    }

    private func smartCleanWholeFile(content: String) async throws -> String {
        let session = LanguageModelSession(instructions: Self.smartInstructions)
        let response = try await session.respond(to: """
        Resolve every Git merge conflict in this file. Return only the cleaned file contents.

        \(content)
        """)

        let cleaned = Self.sanitizeModelOutput(response.content)
        guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CleanerError.emptyResponse
        }
        guard !Self.containsConflictMarkers(cleaned) else {
            throw CleanerError.markersRemain
        }
        return cleaned.hasSuffix("\n") ? cleaned : cleaned + "\n"
    }

    private func smartCleanByConflict(content: String, conflicts: [ConflictBlock]) async throws -> String {
        let session = LanguageModelSession(instructions: Self.perConflictInstructions)
        var result = content

        // Resolve from last to first so string ranges stay valid.
        for conflict in conflicts.reversed() {
            let prompt = """
            Resolve this single Git merge conflict. Return only the replacement code for the conflicted region \
            (no markers, no explanation). Prefer a correct, compiling result. Combine both sides when both add \
            useful unique lines.

            HEAD:
            \(conflict.head)

            Incoming:
            \(conflict.incoming)
            """

            let response = try await session.respond(to: prompt)
            var replacement = Self.sanitizeModelOutput(response.content)
            if replacement.hasSuffix("\n") {
                replacement = String(replacement.dropLast())
            }

            let nsRange = NSRange(conflict.fullRange, in: result)
            guard nsRange.location != NSNotFound,
                  let range = Range(nsRange, in: result) else {
                continue
            }
            result.replaceSubrange(range, with: replacement)
        }

        guard !Self.containsConflictMarkers(result) else {
            throw CleanerError.markersRemain
        }
        return result
    }

    // MARK: - Conflict parsing

    private struct ConflictBlock {
        let fullRange: Range<String.Index>
        let head: String
        let incoming: String
    }

    private func extractTopLevelConflicts(from content: String) -> [ConflictBlock] {
        let lines = content.components(separatedBy: .newlines)
        var conflicts: [ConflictBlock] = []
        var index = 0
        var location = content.startIndex

        func advance(past line: String, isLast: Bool) {
            if line.count > 0 {
                location = content.index(location, offsetBy: line.count)
            }
            if !isLast, location < content.endIndex, content[location] == "\n" {
                location = content.index(after: location)
            }
        }

        while index < lines.count {
            let line = lines[index]
            let lineStart = location
            let isLastLine = index == lines.count - 1

            if line.hasPrefix("<<<<<<<") {
                let conflictStart = lineStart
                advance(past: line, isLast: isLastLine)
                index += 1

                var headLines: [String] = []
                var incomingLines: [String] = []
                var inIncoming = false
                var depth = 1

                while index < lines.count {
                    let current = lines[index]
                    let currentIsLast = index == lines.count - 1
                    let currentStart = location

                    if current.hasPrefix("<<<<<<<") {
                        depth += 1
                        if inIncoming {
                            incomingLines.append(current)
                        } else {
                            headLines.append(current)
                        }
                        advance(past: current, isLast: currentIsLast)
                        index += 1
                        continue
                    }

                    if current.hasPrefix("=======") && depth == 1 && !inIncoming {
                        inIncoming = true
                        advance(past: current, isLast: currentIsLast)
                        index += 1
                        continue
                    }

                    if current.hasPrefix(">>>>>>>") {
                        depth -= 1
                        if depth == 0 {
                            let conflictEnd: String.Index
                            if currentIsLast {
                                conflictEnd = content.endIndex
                            } else {
                                conflictEnd = content.index(currentStart, offsetBy: current.count + 1)
                            }
                            conflicts.append(
                                ConflictBlock(
                                    fullRange: conflictStart..<conflictEnd,
                                    head: headLines.joined(separator: "\n"),
                                    incoming: incomingLines.joined(separator: "\n")
                                )
                            )
                            advance(past: current, isLast: currentIsLast)
                            index += 1
                            break
                        } else {
                            if inIncoming {
                                incomingLines.append(current)
                            } else {
                                headLines.append(current)
                            }
                            advance(past: current, isLast: currentIsLast)
                            index += 1
                            continue
                        }
                    }

                    if inIncoming {
                        incomingLines.append(current)
                    } else {
                        headLines.append(current)
                    }
                    advance(past: current, isLast: currentIsLast)
                    index += 1
                }
            } else {
                advance(past: line, isLast: isLastLine)
                index += 1
            }
        }

        return conflicts
    }

    // MARK: - Output helpers

    private static let smartInstructions = """
        You resolve Git merge conflicts in source code and config files.
        For each conflict marked with <<<<<<<, =======, and >>>>>>>, choose the better side \
        or carefully combine both when each contributes unique correct lines.
        Remove every conflict marker. Preserve all non-conflicted content exactly.
        Return only the final file contents. No markdown, no explanation, no code fences.
        """

    private static let perConflictInstructions = """
        You resolve a single Git merge conflict.
        Return only the resolved replacement text for that region.
        No conflict markers, no markdown fences, no explanation.
        """

    private static func containsConflictMarkers(_ text: String) -> Bool {
        text.contains("<<<<<<<") || text.contains(">>>>>>>")
    }

    private static func sanitizeModelOutput(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if result.hasPrefix("```") {
            if let firstNewline = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: firstNewline)...])
            }
            if result.hasSuffix("```") {
                result = String(result.dropLast(3))
            }
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }
}
