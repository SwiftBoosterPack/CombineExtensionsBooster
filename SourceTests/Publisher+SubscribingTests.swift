//
//  Publisher+SubscribingTests.swift
//
//  Created by Mike Welsh on 2024-02-03.
//

import Combine
import CombineExtensionsBooster
import Foundation
import XCTest

final class Publisher_SubscribingTests: XCTestCase {

  func testSubscriptionReceivesValues() {
    // Arrange
    let publisher = PassthroughSubject<String, Never>()
    let expectation = expectation(description: "Receive values")

    // Act
    publisher.subscribe(self, onValue:  {
      // Receives values!
      expectation.fulfill()
      XCTAssertEqual($0, "ValueOne")
    })
    publisher.send("ValueOne")

    // Assert
    waitForExpectations(timeout: 0.1)
  }

  func testSubscriptionReceivesCompletionSuccess() {
    // Arrange
    let publisher = PassthroughSubject<String, Never>()
    let expectation = expectation(description: "Receive Completion")

    // Act
    publisher.subscribe(self, onCompletion:  {
      // Receives completion!
      switch $0 {
      case .finished:
        expectation.fulfill()
      case .failure(_):
        XCTFail()
      }
    })
    publisher.send(completion: .finished)

    // Assert
    waitForExpectations(timeout: 0.1)
  }

  func testSubscriptionReceivesCompletionFailure() {
    // Arrange
    let publisher = PassthroughSubject<String, Error>()
    let expectation = expectation(description: "Receive Completion")

    // Act
    publisher.subscribe(self, onCompletion:  {
      // Receives completion!
      switch $0 {
      case .finished:
        XCTFail()
      case .failure(_):
        expectation.fulfill()
      }
    })
    publisher.send(completion: .failure(NSError()))

    // Assert
    waitForExpectations(timeout: 0.1)
  }

  func testSubscriptionReceivesValuesAndCompletion() {
    // Arrange
    let publisher = PassthroughSubject<String, Error>()
    let values = ["One", "Two", "Three"]
    let valuesExpectation = expectation(description: "Receive Value")
    valuesExpectation.expectedFulfillmentCount = values.count
    let completionExpectation = expectation(description: "Receive Completion")
    var capturedValues = [String]()

    // Act
    publisher.subscribe(self,
                        onValue: {
      capturedValues.append($0)
      valuesExpectation.fulfill()
    },
                        onCompletion:  {
      // Receives completion!
      switch $0 {
      case .finished:
        completionExpectation.fulfill()
      case .failure(_):
        XCTFail()
      }
    })
    for value in values {
      publisher.send(value)
    }
    publisher.send(completion: .finished)

    // Assert
    waitForExpectations(timeout: 0.1)
    XCTAssertEqual(capturedValues, values)
  }

  func testSubscriptionReceivesValuesAndCompletionAfterCompletion() {
    // Arrange
    let publisher = PassthroughSubject<String, Error>()
    let values = ["One", "Two", "Three"]
    let secondValues = ["Four, Five", "Six"]
    let valuesExpectation = expectation(description: "Receive Value")
    valuesExpectation.expectedFulfillmentCount = values.count
    let completionExpectation = expectation(description: "Receive Completion")
    var capturedValues = [String]()
    weak var cancellable: AnyCancellable?

    // Act
    do {
      cancellable = publisher.subscribe(self,
                                        onValue: {
        capturedValues.append($0)
        valuesExpectation.fulfill()
      },
                                        onCompletion:  {
        // Receives completion!
        switch $0 {
        case .finished:
          completionExpectation.fulfill()
        case .failure(_):
          XCTFail()
        }
      })
    }
    for value in values {
      publisher.send(value)
    }
    publisher.send(completion: .finished)
    for value in secondValues {
      publisher.send(value)
    }

    // Assert
    waitForExpectations(timeout: 0.1)
    // Cancellable still exists because it is not auto-removed.
    XCTAssertNotNil(cancellable)
    XCTAssertEqual(capturedValues, values)
  }

  func testSubscriptionHolderDeallocates_valuesNotSent() {
    // Arrange
    let publisher = PassthroughSubject<String, Never>()
    let expectation = expectation(description: "Receive values")
    expectation.isInverted = true
    weak var object: AnyObject?

    // Act
    do {
      let subscriptionHolder = NSObject()
      object = subscriptionHolder
      publisher.subscribe(subscriptionHolder,
                          onValue:  { _ in
        // Receives values!
        expectation.fulfill()
      },
                          onCompletion: { _ in
        // Receives completion!
        expectation.fulfill()
      })
    }
    // The object should now be deallocated, so the subscription removed when
    // the resulting `AnyCancellable` was also removed.
    XCTAssertNil(object)
    publisher.send("ValueOne")

    // Assert
    waitForExpectations(timeout: 0.1)
  }

  func testSubscriptionCancelledValuesNotSent() {
    // Arrange
    let publisher = PassthroughSubject<String, Never>()
    let expectation = expectation(description: "Receive values")
    expectation.isInverted = true

    // Act
    let cancellable = publisher.subscribe(self, onValue:  {
      // Receives values!
      expectation.fulfill()
      XCTAssertEqual($0, "ValueOne")
    })

    cancellable.cancel()
    publisher.send("ValueOne")

    // Assert
    waitForExpectations(timeout: 0.1)
  }

  func testSubscription_autoRemove_completionFinishes() {
    // Arrange
    let publisher = PassthroughSubject<String, Never>()
    let valueExpectation = expectation(description: "Receive values")
    valueExpectation.isInverted = true
    let completionExpectation = expectation(description: "Received Completion")
    weak var cancellable: AnyCancellable?

    // Act
    do {
      cancellable = publisher.subscribe(self,
                                        autoRemove: true,
                                        onValue:  {
        // Receives values!
        valueExpectation.fulfill()
        XCTAssertEqual($0, "ValueOne")
      },
                                        onCompletion: {
        switch $0 {
        case .finished:
          completionExpectation.fulfill()
        case .failure:
          XCTFail()
        }
      })
    }

    publisher.send(completion: .finished)
    publisher.send("ValueOne")

    // Assert
    waitForExpectations(timeout: 0.1)
    // Cancellable is nil because it's auto-removed.
    XCTAssertNil(cancellable)
  }

  func testSubscription_autoRemove_failureFinishes() {
    // Arrange
    let publisher = PassthroughSubject<String, Error>()
    let valueExpectation = expectation(description: "Receive values")
    valueExpectation.isInverted = true
    let completionExpectation = expectation(description: "Received Completion")

    // Act
    publisher.subscribe(self,
                                          autoRemove: true,
                                          onValue:  {
      // Receives values!
      valueExpectation.fulfill()
      XCTAssertEqual($0, "ValueOne")
    },
                                          onCompletion: {
      switch $0 {
      case .finished:
        XCTFail()
      case .failure:
        completionExpectation.fulfill()
      }
    })

    publisher.send(completion: .failure(NSError()))
    publisher.send("ValueOne")

    // Assert
    waitForExpectations(timeout: 0.1)
  }

  func testConcurrentlySubscribeAndPublishValues() {
    // Arrange
    let publisher = PassthroughSubject<String, Never>()
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
        publisher.subscribe(self, onValue: { _ in })
        let localObject = NSObject()
        publisher.subscribe(localObject, onCompletion: { _ in})
        publisher.send("\(i)")
        dispatchGroup.leave()
      }
    }

    // Notify the expectation when all concurrent operations complete
    dispatchGroup.wait()

    // Assert
    // No explicit assertions; shouldn't crash during test.
  }
}
