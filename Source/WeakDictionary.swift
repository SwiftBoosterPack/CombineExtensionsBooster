//
//  WeakDictionary.swift
//
//
//  Created by Mike Welsh on 2024-02-03.
//

import ConcurrencyBooster
import Foundation
import ObjectiveC

/// A class which removes the values of the dictionary when a key is deallocated.
/// The weak dictionary is threadsafe through the use of `@Synchronized` on the internal storage.
///
/// Note: Because the `Key` can be `AnyObject` - the values are stored directly in relation to that object reference.
/// Using equatable objects will not retrieve the same key.
class WeakDictionary<Key: AnyObject, Value> {
  @Synchronized private var dictionary = [ObjectIdentifier: Value]()

  subscript(key: Key) -> Value? {
    get {
      let objectIdentifier = ObjectIdentifier(key)
      return dictionary[objectIdentifier]
    }
    set {
      let objectIdentifier = ObjectIdentifier(key)
      installDeallocHook(key, objectIdentifier)
      dictionary[objectIdentifier] = newValue
    }
  }

  /// Retrieves all the keys currently held.
  func allKeys() -> [ObjectIdentifier] {
    return Array(dictionary.keys)
  }

  /// Retrieves all the values currently held.
  func allValues() -> [Value] {
    return Array(dictionary.values)
  }

  private func installDeallocHook(_ key: Key, _ identifier: ObjectIdentifier) {
    let remover: WeakKeyRemover
    let existingRemover = objc_getAssociatedObject(key, &ValueAssociation.associatedKey)
    if let existing = existingRemover as? WeakKeyRemover {
      // We don't need to associate another removal - use the existing one.
      remover = existing
    } else {
      remover = WeakKeyRemover { [identifier, weak self] in
        guard let self else { return }
        dictionary[identifier] = nil
      }
    }
    // The weak value we are wrapping must hold onto this WeakKey until it is deallocated
    // which will then trigger the instance of self to deallocate.
    objc_setAssociatedObject(key, &ValueAssociation.associatedKey, remover, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
  }

  /// A class we associate with the value T such that when T is deallocated, we remove `WeakKey` from `WeakDictionary`
  private class WeakKeyRemover {
    private let removalCallback: () -> Void

    init(_ removal: @escaping () -> Void) {
      removalCallback = removal
    }

    deinit {
      removalCallback()
    }
  }
}

/// Internal class which just works as an way to access `associatedKey`
private class ValueAssociation {
  // A key for the association
  fileprivate static var associatedKey: UInt8 = 0
}
