//
//  Publisher_ExponentialRetry.swift
//  
//
//  Created by Mike Welsh on 2024-04-18.
//

import Combine
import CombineSchedulers
import Foundation
import XCTest

final class Publisher_ExponentialRetry: XCTestCase {
  
  func testExponentialRetryValueSentImmediately() {
    var capturedValue = -1
    var didFinish: Bool = false

    let sut = PassthroughSubject<Int, Error>()
    let testScheduler = DispatchQueue.test

    // Must keep a reference to the cancellable otherwise the sink will not send values.
    let cancellable = sut.exponentialRetry(3, withBackoff: 1, scheduler: testScheduler)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .failure:
          XCTFail()
        case .finished:
          didFinish = true
        }
      }) { value in
        capturedValue = value
      }
    
    // Send a success and completion
    XCTAssertFalse(didFinish)
    XCTAssertEqual(-1, capturedValue)
    sut.send(1)
    sut.send(completion: .finished)
    XCTAssertEqual(1, capturedValue)
    XCTAssertTrue(didFinish)
    cancellable.cancel()
  }
  
  func testExponentialRetryValueSent() {
    let errorCode = 10
    var capturedValue = -1
    var didFinish: Bool = false

    let sut = PassthroughSubject<Int, Error>()
    let testScheduler = DispatchQueue.test

    // Must keep a reference to the cancellable otherwise the sink will not send values.
    let cancellable = sut
      .tryMap { value in
        // Fail is the value is 10. A PassthroughSubject will not emit any more values if a failure is sent.
        // So cause failures this way.
        if value == errorCode {
          throw NSError(domain: "combineextensionbooster", code: 10)
        }
        return value
      }
      .exponentialRetry(3, withBackoff: 1, scheduler: testScheduler)
      .sink(receiveCompletion: { completion in
        switch completion {
        case .failure:
          XCTFail()
        case .finished:
          didFinish = true
        }
      }) { value in
        capturedValue = value
      }

    // Send an error
    sut.send(errorCode)
    // Advance one second
    testScheduler.advance(by: 1)

    // Send another failure and validate the exponential increase
    sut.send(errorCode)
    // With the exponential backoff, we must increase by 2 seconds.
    testScheduler.advance(by: 2)
    
    // Send a success and completion
    XCTAssertFalse(didFinish)
    XCTAssertEqual(-1, capturedValue)
    sut.send(1)
    sut.send(completion: .finished)
    XCTAssertEqual(1, capturedValue)
    XCTAssertTrue(didFinish)
    cancellable.cancel()
  }

  func testExponentialRetryEndsInFailure() {
    let errorCode = 10
    var capturedRetries = [Int]()
    var capturedError: Error? = nil

    let sut = PassthroughSubject<Int, Error>()
    let testScheduler = DispatchQueue.test

    // Must keep a reference to the cancellable otherwise the sink will not send values.
    let cancellable = sut
      .tryMap { value in
        // Fail is the value is 10. A PassthroughSubject will not emit any more values if a failure is sent.
        // So cause failures this way.
        if value == errorCode {
          throw NSError(domain: "combineextensionbooster", code: 10)
        }
        return value
      }
      .exponentialRetry(3, withBackoff: 1, scheduler: testScheduler, retryAction: { capturedRetries.append(1) })
      .sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          capturedError = error
        case .finished:
          XCTFail()
        }
      }) { value in
        
      }

    // No failure, no captured output.
    XCTAssertTrue(capturedRetries.isEmpty)
    // Send an error
    sut.send(errorCode)
    // No time incremented, so nothing captured yet.
    XCTAssertTrue(capturedRetries.isEmpty)
    // Advance one second
    testScheduler.advance(by: 1)
    XCTAssertEqual(capturedRetries.count, 1)

    // Send another failure and validate the exponential increase
    sut.send(errorCode)
    XCTAssertEqual(capturedRetries.count, 1)
    // With the exponential backoff, we must increase by 2 seconds so 1 second should do nothing.
    testScheduler.advance(by: 1)
    // Validate only one captured retry still.
    XCTAssertEqual(capturedRetries.count, 1)
    testScheduler.advance(by: 1)
    // Now we should have two.
    XCTAssertEqual(capturedRetries.count, 2)
    XCTAssertNil(capturedError)

    // Send another failure and validate the exponential increase
    sut.send(errorCode)
    XCTAssertEqual(capturedRetries.count, 2)
    // With the exponential backoff, we must increase by 4 seconds now
    testScheduler.advance(by: 4)
    XCTAssertEqual(capturedRetries.count, 3)

    // We have hit the retry limit - send another error which should result in capturing the error.
    XCTAssertNil(capturedError)
    sut.send(errorCode)
    // The failure is delayed until the last scheduled delay.
    testScheduler.advance(by: 8)
    XCTAssertNotNil(capturedError)
    // There is not another retry action after the final retry finishes.
    XCTAssertEqual(capturedRetries.count, 3)
    cancellable.cancel()
  }
}
