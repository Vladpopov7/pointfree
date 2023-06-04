import Combine

// it's called Effect because it handles side effects
public struct Effect<Output>: Publisher {
    public typealias Failure = Never

    let publisher: AnyPublisher<Output, Failure>
    
    public func receive<S>(
        subscriber: S
    ) where S: Subscriber, Never == S.Failure, Output == S.Input {
        self.publisher.receive(subscriber: subscriber)
    }
}

extension Effect {
    public static func fireAndForget(work: @escaping () -> Void) -> Effect {
        return Deferred { () -> Empty<Output, Never> in
            work()
            return Empty(completeImmediately: true)
        }.eraseToEffect()
    }
    
    public static func sync(work: @escaping () -> Output) -> Effect {
        // we don't want this to be eager effect, that's why we use Deferred
        return Deferred {
            Just(work())
        }.eraseToEffect()
    }
}

extension Publisher where Failure == Never {
    public func eraseToEffect() -> Effect<Output> {
        return Effect(publisher: self.eraseToAnyPublisher())
    }
}

extension Publisher where Output == Never, Failure == Never {
    public func fireAndForget<A>() -> Effect<A> {
        return self.map(absurd).eraseToEffect()
    }
}

func absurd<A>(_ never: Never) -> A {
    // never has no cases, but since the compiler has gotten smarter, we can even not switch on an empty enum
//    switch never {}
}
