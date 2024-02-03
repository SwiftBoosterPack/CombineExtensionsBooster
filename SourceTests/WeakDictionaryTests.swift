//
//  File.swift
//  
//
//  Created by Mike Welsh on 2024-02-03.
//

@testable import CombineExtensionsBooster
import XCTest

/// Tests for ``WeakDictionary``
final class WeakDictionaryTests: XCTestCase {
  func testKeyValueRetrieval() {
    // Arrange
    let weakDict = WeakDictionary<MyClass, String>()
    let key1 = MyClass(id: 1)
    let key2 = MyClass(id: 2)
    // Act
    weakDict[key1] = "Value for MyClass 1"
    weakDict[key2] = "Value for MyClass 2"
    // Assert
    XCTAssertEqual(weakDict[key1], "Value for MyClass 1")
    XCTAssertEqual(weakDict[key2], "Value for MyClass 2")
  }

  func testKeyDeallocation() {
    // Arrange
    let weakDict = WeakDictionary<MyClass, String>()
    let key1 = MyClass(id: 1)

    weak var key2: MyClass?

    // Act
    do {
      // Put the value within this scope, but key1 exists in the outer scope
      weakDict[key1] = "Value for MyClass 1"
      let key = MyClass(id: 2)
      key2 = key
      weakDict[key] = "Value for MyClass 2"
      XCTAssertNotNil(weakDict[key])
    }
    // Trigger deallocation of the key by exiting the scope

    // Assert
    XCTAssertNil(key2)
    XCTAssertEqual(weakDict.allKeys().count, 1)
    XCTAssertEqual(weakDict[key1], "Value for MyClass 1")
  }

  func testSameEquatableKeyValueRetrieval() {
    // Arrange
    let weakDict = WeakDictionary<MyClass, String>()
    let key1 = MyClass(id: 1)
    let key2 = MyClass(id: 1)
    // Act
    weakDict[key1] = "Value for MyClass 1"
    weakDict[key2] = "Value for MyClass 2"
    // Assert
    XCTAssertEqual(weakDict[key1], "Value for MyClass 1")
    XCTAssertEqual(weakDict[key2], "Value for MyClass 2")
  }

  func testDictionaryCleanUp() {
    // Arrange
    // Create weak references to all the objects, and then set them within a confined scope.
    // When exiting the scope, they should all be cleaned up and deallocated.
    weak var weakWeakDict: WeakDictionary<MyClass, MyClass>?
    weak var key1: MyClass?
    weak var value1: MyClass?

    // Act
    do {
      let internalWeakDict = WeakDictionary<MyClass, MyClass>()
      let internalKey1 = MyClass(id: 1)
      let internalValue1 = MyClass(id: 999)
      weakWeakDict = internalWeakDict
      key1 = internalKey1
      value1 = internalValue1
      internalWeakDict[internalKey1] = internalValue1
    }

    // Assert
    XCTAssertNil(weakWeakDict)
    XCTAssertNil(key1)
    XCTAssertNil(value1)
  }

  func testConcurrencySafety() {
    // Arrange
    let weakDict = WeakDictionary<MyClass, String>()
    // Dispatch the operations on a concurrent queue
    let concurrentQueue = DispatchQueue(label: "com.example.concurrentQueue", attributes: .concurrent)
    // Number of concurrent operations
    let operationCount = 1000
    // Use a dispatch group to wait for all operations to complete
    let dispatchGroup = DispatchGroup()

    // Act
    for i in 0..<operationCount {
      dispatchGroup.enter()
      // Concurrently add and retrieve values
      concurrentQueue.async {
        let key = MyClass(id: i)
        weakDict[key] = "Value for MyClass \(i)"
        if let retrievedValue = weakDict[key] {
          print("Retrieved value: \(retrievedValue) for key \(key.id)")
        } else {
          XCTFail("Failed to retrieve value for key \(key.id)")
        }
        dispatchGroup.leave()
      }
    }

    // Notify the expectation when all concurrent operations complete
    dispatchGroup.wait()

    // Assert
    // No explicit assertions; shouldn't crash during test.
  }
}

// Your MyClass implementation
private class MyClass: Equatable {
  static func == (lhs: MyClass, rhs: MyClass) -> Bool {
    lhs.id == rhs.id
  }

  let id: Int

  init(id: Int) {
    self.id = id
    print("MyClass \(id) initialized")
  }

  deinit {
    print("MyClass \(id) deallocated")
  }
}
