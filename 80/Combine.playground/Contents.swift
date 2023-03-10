
public struct Effect<A> {
  public let run: (@escaping (A) -> Void) -> Void

  public func map<B>(_ f: @escaping (A) -> B) -> Effect<B> {
    return Effect<B> { callback in self.run { a in callback(f(a)) } }
  }
}

import Dispatch

let anIntInTwoSeconds = Effect<Int> { callback in
  DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    callback(42)
    callback(1729)
  }
}

// laziness - effect of not doing work immediately (the opposite is eager)
anIntInTwoSeconds.run { int in print(int) }

//anIntInTwoSeconds.map { $0 * $0 }.run { int in print(int) }

import Combine

//Publisher.init

//AnyPublisher.init(<#T##publisher: Publisher##Publisher#>)


var count = 0
let iterator = AnyIterator<Int>.init {
  count += 1
  return count
}
Array(iterator.prefix(10))

// Deferred - это не eager publisher (lazy?), если на него не будет подписки, то действия не будут производиться, поэтому если в него обернуть Future и не подписаться, то "Hello from the future" не выведется
let aFutureInt = Deferred {
    // Future - это eager publisher, если даже никто не подписан на него, но он был создан, то все равно асинхронная работа произведется и будет print "Hello from the future"
  Future<Int, Never> { callback in
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      print("Hello from the future")
      callback(.success(42))
      callback(.success(1729))
    }
  }
}

//aFutureInt.subscribe(AnySubscriber<Int, Never>.init(
//  receiveSubscription: { subscription in
//    print("subscription")
//    subscription.cancel()
//    subscription.request(.unlimited)
//},
//  receiveValue: { value -> Subscribers.Demand in
//    print("value", value)
//    return .unlimited
//},
//  receiveCompletion: { completion in
//    print("completion", completion)
//}
//))

let cancellable = aFutureInt.sink { int in
  print(int)
}
//cancellable.cancel()

//Subject.init

let passthrough = PassthroughSubject<Int, Never>.init()
let currentValue = CurrentValueSubject<Int, Never>.init(2)

let c1 = passthrough.sink { x in
  print("passthrough", x)
}
let c2 = currentValue.sink { x in
  print("currentValue", x)
}

passthrough.send(42)
currentValue.send(1729)
passthrough.send(42)
currentValue.send(1729)
