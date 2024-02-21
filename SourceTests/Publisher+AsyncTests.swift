//
//  File.swift
//  
//
//  Created by Mike Welsh on 2024-02-20.
//

import Combine
import CombineExtensionsBooster
import Foundation
import XCTest

final class Publisher_AsyncTests: XCTestCase {
  
  func testAsyncReturnsValue() {
    // Arrange
    let value = "ValueOne"
    let publisher = PassthroughSubject<String, Never>()
    let expectation = expectation(description: "Receive values")

    // Act
    Task {
      let result = try await publisher.eraseToAnyPublisher().async()
      XCTAssertEqual(result, value)
      expectation.fulfill()
    }
    // We want the async task to have time to setup before we send a value, so send the value
    // async.
    DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
      publisher.send(value)
    }

    // Assert
    waitForExpectations(timeout: 1.1)
  }
  
  func testAsyncThrows() {
    // Arrange
    let value = "ValueOne"
    let sentError = NSError()
    let publisher = PassthroughSubject<String, Error>()
    let valueExpectation = expectation(description: "Receive values")
    valueExpectation.isInverted = true
    let exceptionExpectation = expectation(description: "Received exception")

    // Act
    Task {
      do {
        let result = try await publisher.eraseToAnyPublisher().async()
        XCTAssertEqual(result, value)
        valueExpectation.fulfill()
      } catch {
        exceptionExpectation.fulfill()
      }
    }
    
    // We want the async task to have time to setup before we send a value, so send the value
    // async.
    DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
      publisher.send(completion: .failure(sentError))
    }

    // Assert
    waitForExpectations(timeout: 1.1)
  }
  
  func testAsyncCompletes() {
    // Arrange
    let value = "ValueOne"
    let publisher = PassthroughSubject<String, Error>()
    let valueExpectation = expectation(description: "Receive values")
    valueExpectation.isInverted = true
    let exceptionExpectation = expectation(description: "Received exception")

    // Act
    Task {
      do {
        let result = try await publisher.eraseToAnyPublisher().async()
        XCTAssertEqual(result, value)
        valueExpectation.fulfill()
      } catch {
        guard error is AsyncError else {
          XCTFail()
          return
        }
        exceptionExpectation.fulfill()
      }
    }
    
    // We want the async task to have time to setup before we send a value, so send the value
    // async.
    DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
      publisher.send(completion: .finished)
    }

    // Assert
    waitForExpectations(timeout: 1.1)
  }
  
  func testAsyncToPublisher() {
    // Arrange
    let valueExpectation = expectation(description: "Receive values")
    let completionExpectation = expectation(description: "Receive completion")
    let asyncClosure: AsyncConvertingPublisher<String>.AsyncClosure = { await self.doubleString("test") }
    
    // Act
    AsyncConvertingPublisher<String>(asyncFunc: asyncClosure)
      .eraseToAnyPublisher()
      .subscribe(self, onValue: {
        XCTAssertEqual($0, "test test")
        valueExpectation.fulfill()
      },
      onCompletion: {
        switch $0 {
        case .finished:
          completionExpectation.fulfill()
        case .failure:
          XCTFail()
        }
      })
    
    // Assert
    waitForExpectations(timeout: 0.1)
  }
  
  func testAsyncToPublisherFailure() {
    // Arrange
    let sentError = NSError()
    let valueExpectation = expectation(description: "Receive values")
    valueExpectation.isInverted = true
    let completionExpectation = expectation(description: "Receive completion")
    let asyncClosure: AsyncConvertingPublisher<String>.AsyncClosure = { throw sentError }
    
    // Act
    AsyncConvertingPublisher<String>(asyncFunc: asyncClosure)
      .eraseToAnyPublisher()
      .subscribe(self, onValue: {
        XCTAssertEqual($0, "test test")
        valueExpectation.fulfill()
      },
      onCompletion: {
        switch $0 {
        case .finished:
          XCTFail()
        case .failure:
          completionExpectation.fulfill()
        }
      })
    
    // Assert
    waitForExpectations(timeout: 0.1)
  }
  
  func doubleString(_ input: String) async -> String {
    return input + " " + input
  }
}
