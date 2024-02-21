//
//  Publisher+Async.swift
//
//
//  Created by Mike Welsh on 2024-02-20.
//

import Combine
import Foundation

/// Error declaration which is emitted when no value is returned.
public enum AsyncError: Error {
    case finishedWithoutValue
}

public extension AnyPublisher {
  /// Converts the publisher to an async  `Output`.
  /// NOTE: This can be problematic if not already working within an async/await stream, as
  /// using a `Task` to convert to async means that values could be missed in the publishing pipeline.
  func async() async throws -> Output {
    // Retrieve the first value - using a direct `true` match since we aren't trying to filter.
    let value = try await self.values.first(where: { _ in true })
    guard let value else {
      throw AsyncError.finishedWithoutValue
    }
    // Return the value.
    return value
  }
}

/// A publisher used to capture an `AsyncClosure`. Each subscription will _re-execute_ the `AsyncClosure` - so be very careful when subscribing.
/// Consider using `.share()` if the publisher is intended to have multiple subscribers to avoid additional `AsyncClosure` executions.
public struct AsyncConvertingPublisher<Output>: Publisher {
  public typealias Output = Output
  public typealias Failure = any Error
  /// Convenience typealias for an async closure matching Output.
  public typealias AsyncClosure = () async throws -> Output
  
  public init(asyncFunc: @escaping AsyncClosure) {
    self.asyncFunc = asyncFunc
  }
  
  public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
    subscriber.receive(subscription: AsyncConvertingPublisherSubscription(subscriber: subscriber, async: asyncFunc))
  }
  
  /// Need to capture a reference to the `async` call so that we can execute it when demand is created.
  private let asyncFunc: AsyncClosure
}

/// Extension used to declare the subscription class.
extension AsyncConvertingPublisher {
  /// Represents a subscription to `AsyncPublisher`
  final class AsyncConvertingPublisherSubscription<S: Subscriber>: Subscription where S.Input == Output, S.Failure == Failure {
    @discardableResult
    init(subscriber: S, async: @escaping AsyncClosure) {
      self.subscriber = subscriber
      self.async = async
    }
    
    /// The subscriber who wants to receive values.
    var subscriber: S?
    /// The task we want to capture as a cancellable when demand is created.
    var task: Task<(), Error>?
    /// The closure to execute when demand is created.
    let async: AsyncClosure
    
    func request(_ demand: Subscribers.Demand) {
      // We don't care about what the particular demand is, since the async is only expected to emit a single result.
      task = Task { [weak self] in
        // If self or the subscription no longer exists, then return nothing.
        guard let self, let subscriber else { return }
        do {
          let value = try await async()
          _ = subscriber.receive(value)
          // We only execute to get a single value. Complete now.
          subscriber.receive(completion: .finished)
        } catch {
          // Something went wrong.
          subscriber.receive(completion: .failure(error))
        }
      }
    }
    
    func cancel() {
      self.subscriber = nil
      task?.cancel()
      task = nil
    }
  }
}
