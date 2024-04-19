//
//  Publisher+ExponentialRetry.swift
//
//
//  Created by Mike Welsh on 2024-04-18.
//

import Combine
import Foundation

public extension Publisher {
  /// Adds an exponential retry to the publisher, with an initial backoff. Runs on the specified scheduler. The final failure message is delayed by the backoff amount.
  /// - Parameters:
  ///   - retries: The number of retries before a failure occurs
  ///   - initialBackoff: The initial backoff time to use on the publisher. Doubles on each retry attempt
  ///   - scheduler: The scheduler to perform the delay on to wait
  ///   - retryAction: An action to perform when the retry occurs. The retry action triggers _after_ the delay.
  func exponentialRetry<S: Scheduler>(_ retries: Int,
                                      withBackoff initialBackoff: S.SchedulerTimeType.Stride,
                                      scheduler: S,
                                      retryAction: @escaping () -> Void = {}) -> AnyPublisher<Output, Error> {
      self
      .tryCatch { error -> AnyPublisher<Output, Failure> in
        var backOff = initialBackoff
        return Just(Void())
          .flatMap { _ -> AnyPublisher<Output, Failure> in
            let result = Just(Void())
              .delay(for: backOff, scheduler: scheduler)
              .flatMap { _ in
                retryAction()
                return self
              }
            backOff = backOff * 2
            return result.eraseToAnyPublisher()
          }
          .retry(retries - 1)
          .eraseToAnyPublisher()
      }
      .eraseToAnyPublisher()
  }
}
