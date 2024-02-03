# CombineExtensionBooster

CombineExtensionsBooster is a Swift package that enhances the capabilities of Combine, Apple's framework for processing values over time. It includes a useful extension for managing subscriptions and associating them with objects, along with a custom operator for Combine publishers.

### Subscription Convenience

```swift
class MyViewModel {
  func createSubscription() {
    // Stores a subscription to the publisher on `self` until `self` is deallocated.
    somePublisher.subscribe(self, onValue: { value in
        // Handle the received value
    }, onCompletion: { completion in
        // Handle the completion
    })
  }
}
```
