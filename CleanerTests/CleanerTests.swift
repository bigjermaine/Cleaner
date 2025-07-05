//
//  CleanerTests.swift
//  CleanerTests
//
//  Created by Daniel Jermaine on 05/07/2025.
//

import XCTest
@testable import Cleaner
import XCTest

class MergeConflictCleanerTests: XCTestCase {
    
    var cleaner: MergeConflictCleaner!
    
    override func setUp() {
        super.setUp()
        cleaner = MergeConflictCleaner()
    }
    
    override func tearDown() {
        cleaner = nil
        super.tearDown()
    }
    
    // Test 1: Simple single conflict
    func testSimpleSingleConflict() {
        let input = """
        func greet() {
            print("Hello")
        <<<<<<< HEAD
            print("Welcome to our app")
        =======
            print("Welcome to the application")
        >>>>>>> feature/greeting
        }
        """
        
        let expected = """
        func greet() {
            print("Hello")
        }
        """
        
        let result = cleaner.clean(content: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    // Test 2: Multiple conflicts in same function
    func testMultipleConflictsInSameFunction() {
        let input = """
        func processData() {
            let data = fetchData()
        <<<<<<< HEAD
            validateData(data)
        =======
            sanitizeData(data)
        >>>>>>> feature/validation
            
            let processed = transform(data)
            
        <<<<<<< HEAD
            saveToDatabase(processed)
        =======
            saveToCache(processed)
            saveToDatabase(processed)
        >>>>>>> feature/caching
        }
        """
        
        let expected = """
        func processData() {
            let data = fetchData()
            
            let processed = transform(data)
            
        }
        """
        
        let result = cleaner.clean(content: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    // Test 3: Nested conflicts (conflict within conflict)
    func testNestedConflicts() {
        let input = """
        class APIClient {
        <<<<<<< HEAD
            func makeRequest() {
                let url = "https://api.example.com"
        <<<<<<< develop
                let method = "GET"
        =======
                let method = "POST"
        >>>>>>> feature/post-support
                performRequest(url: url, method: method)
            }
        =======
            func executeRequest() {
                let endpoint = "https://api.newservice.com"
                sendRequest(to: endpoint)
            }
        >>>>>>> feature/new-api
        }
        """
        
        let expected = """
        class APIClient {
        }
        """
        
        let result = cleaner.clean(content: input)
        print(result)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    // Test 4: Property conflicts
    func testPropertyConflicts() {
        let input = """
        struct User {
            let id: String
            let name: String
        <<<<<<< HEAD
            let email: String
            let phone: String?
        =======
            let emailAddress: String
            let phoneNumber: String?
            let isVerified: Bool
        >>>>>>> feature/user-verification
            
            init(id: String, name: String) {
                self.id = id
                self.name = name
            }
        }
        """
        
        let expected = """
        struct User {
            let id: String
            let name: String
            
            init(id: String, name: String) {
                self.id = id
                self.name = name
            }
        }
        """
        
        let result = cleaner.clean(content: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    // Test 5: Import conflicts
    func testImportConflicts() {
        let input = """
        <<<<<<< HEAD
        import Foundation
        import UIKit
        import CoreData
        =======
        import Foundation
        import SwiftUI
        import Combine
        >>>>>>> feature/swiftui-migration
        
        class ViewController {
            func viewDidLoad() {
                setupUI()
            }
        }
        """
        
        let expected = """
        
        class ViewController {
            func viewDidLoad() {
                setupUI()
            }
        }
        """
        
        let result = cleaner.clean(content: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // Test 7: No conflicts (should return original)
    func testNoConflicts() {
        let input = """
        func simpleFunction() {
            print("Hello, World!")
            return "Success"
        }
        
        class SimpleClass {
            var property: String = "value"
            
            func method() {
                // This is a comment
                doSomething()
            }
        }
        """
        
        let result = cleaner.clean(content: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      input.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    
    // Test 9: Only conflict markers (edge case)
    func testOnlyConflictMarkers() {
        let input = """
        <<<<<<< HEAD
        =======
        >>>>>>> feature/test
        """
        
        let expected = ""
        let result = cleaner.clean(content: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), expected)
    }
    
    // Test 10: Performance test with large content
    func testPerformanceWithLargeContent() {
        var largeInput = ""
        for i in 0..<1000 {
            largeInput += """
            func function\(i)() {
                print("Function \(i)")
            <<<<<<< HEAD
                return "version1"
            =======
                return "version2"
            >>>>>>> feature/branch\(i)
            }
            
            """
        }
        
        measure {
            _ = cleaner.clean(content: largeInput)
        }
    }
}

// MARK: - Test Data Generator
extension MergeConflictCleanerTests {
    
    /// Generates a test merge conflict for manual testing
    static func generateTestConflict() -> String {
        return """
        // Test all scenarios with this comprehensive example
        import Foundation
        
        <<<<<<< HEAD
        import UIKit
        import CoreData
        =======
        import SwiftUI
        import Combine
        >>>>>>> feature/swiftui
        
        class DataManager {
            
        <<<<<<< HEAD
            var storage: [String: Any] = [:]
            
            func save(key: String, value: Any) {
                storage[key] = value
                print("Saved to memory")
            }
        =======
            var database: CoreDataStack = CoreDataStack()
            
            func save(key: String, value: Any) {
                database.save(key: key, value: value)
                print("Saved to database")
            }
        >>>>>>> feature/persistence
            
            func load(key: String) -> Any? {
        <<<<<<< HEAD
                return storage[key]
        =======
                return database.load(key: key)
        >>>>>>> feature/persistence
            }
        }
        """
    }
}
