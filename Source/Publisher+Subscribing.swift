//
//  Publisher+Subscribing.swift
//
//
//  Created by Mike Welsh on 2024-02-03.
//

import Combine
import Foundation

public extension Publisher {
  
  /// Subscribes for values and completions from the Publisher, internally using `sink(receiveCompletion:receiveValue:)` and
  /// therefore creating demand.
  ///
  /// - Parameters:
  ///   - subscriber: The `subscriber` to associate the `AnyCancellable` to. This is weakly held such that
  ///   if the `subscriber` is deallocated the `AnyCancellable` will also be released.
  ///   - autoRemove: If set to `true`, removes the reference to the `AnyCancellable` when a completion value is received. This
  ///   may be appropriate for use when singleton-like objects subscribe to streams.
  ///   - onValue: The closure to call when receiving a stream value
  ///   - onCompletion: The closure to call when receiving a stream completion.
  @discardableResult
  func subscribe(_ subscriber: AnyObject,
                 autoRemove: Bool = false,
                 onValue: @escaping (Output) -> Void = { _ in },
                 onCompletion: @escaping (Subscribers.Completion<Failure>) -> Void = { _ in })
  -> AnyCancellable {
    /// Create a reference holder here so that we can set the `AnyCancellable` on it from
    /// the `sink(receiveCompletion:receiveValue:)` call.
    let referenceHolder = ReferenceHolder<AnyCancellable>()
    let cancellable = sink(receiveCompletion: { [weak subscriber, weak referenceHolder] in
      onCompletion($0)
      if (autoRemove) {
        // If the subscriber no longer exists, there's nothing to remove.
        guard let subscriber, let referenceHolder else { return }
        SubscriptionHolder.remove(object: subscriber, referenceHolder: referenceHolder)
      }
    },
                           receiveValue: onValue)
    referenceHolder.reference = cancellable
    /// Store the subscriber with the reference holder in the `SubscriptionHolder` - internally using a `WeakDictionary`.
    SubscriptionHolder.store(object: subscriber, referenceHolder: referenceHolder)
    return cancellable
  }
}

/// A private static class which holds onto subscriptions, associating them to the object provided.
private enum SubscriptionHolder {
  private static let subscriptions = WeakDictionary<AnyObject, SafeCollection<ReferenceHolder<AnyCancellable>>>()
  private static let arrayLock = NSRecursiveLock()

  /// Stores the `AnyCancellable` through the `ReferenceHolder`
  /// - Parameters:
  ///   - object: The object to associate the `AnyCancellable` to.
  ///   - referenceHolder: The holder of the `AnyCancellable`.
  fileprivate static func store(object: AnyObject, referenceHolder: ReferenceHolder<AnyCancellable>) {
    let safeCollection = subscriptions[object] ?? SafeCollection()
    safeCollection.addItem(referenceHolder)
    subscriptions[object] = safeCollection
  }

  /// Removes the `AnyCancellable` through the `ReferenceHolder`
  /// - Parameters:
  ///   - object: The object associated with the `AnyCancellable`.
  ///   - referenceHolder: The holder of the `AnyCancellable`.
  fileprivate static func remove(object: AnyObject, referenceHolder: ReferenceHolder<AnyCancellable>) {
    guard let safeCollection = subscriptions[object] else {
      // No subscriptions for the provided object
      return
    }

    safeCollection.removeItem(referenceHolder)
  }
}

/// A reference holder which is used to hold a strong pointer to a reference.
/// This is created to allow auto-removal, where access to the `AnyCancellable` would otherwise not
/// be able to be captured since it is returned as a result of the `sink(receiveCompletion:receiveValue:)` call.
private class ReferenceHolder<T> {
  var reference: T?

  init(_ reference: T? = nil) {
    self.reference = reference
  }
}

/// An class which performs operations using a lock to ensure thread safety.
private class SafeCollection<T: AnyObject> {
  private let lock = NSRecursiveLock()
  private var array = [T]()

  func addItem(_ item: T) {
    lock.synchronized {
      array.append(item)
    }
  }

  func removeItem(_ item: T) {
    lock.synchronized {
      if let index = array.firstIndex(where: { $0 === item }) {
        // Found the referenceHolder, remove it from the array
        array.remove(at: index)
      }
    }
  }
}
