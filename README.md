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


### Async/Await Compatibility

#### Convert Async/Await into a Combine stream
```swift
class MyViewModel {

  func createSubscription() {
    // Async function can now be merged with other Combine streams.
    AsyncPublisher({ await self.someAsyncTask() })
      .eraseToAnyPublisher()
      .subscribe(self, onValue: { value in
        // Handle the value
      })
  }

  func someAsyncTask() async -> String {
    ...
  }
}
```

#### Convert Combine stream into an Async

```swift
class MyClass {
  func performWork() async -> String {
    let myWorkStream = workStream()
    let value = try await myWorkStream.async()
    return value
  }
  
  func workStream() -> AnyPublisher<String, Never> {
    ...
  }
}
```
