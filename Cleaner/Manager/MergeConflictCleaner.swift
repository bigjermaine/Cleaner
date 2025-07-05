//
//  MergeConflictCleaner.swift
//  Cleaner
//
//  Created by Daniel Jermaine on 05/07/2025.
//

import Foundation

class MergeConflictCleaner {
    
    enum ConflictResolution {
        case head          // Keep HEAD version (first section)
        case incoming      // Keep incoming branch version (second section)
        case removeAll     // Remove all conflicted sections
    }
    
    func clean(content: String, resolution: ConflictResolution = .head) -> String {
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

            // Determine if we should include this line
            let shouldIncludeLine: Bool
            
            if conflictDepth == 0 {
                // Always include lines outside conflicts
                shouldIncludeLine = true
            } else {
                // Inside a conflict - decide based on resolution strategy
                switch resolution {
                case .head:
                    shouldIncludeLine = inHeadSection
                case .incoming:
                    shouldIncludeLine = inIncomingSection
                case .removeAll:
                    shouldIncludeLine = false
                }
            }
            
            if shouldIncludeLine {
                result += line + "\n"
            }
        }

        return result
    }
}

