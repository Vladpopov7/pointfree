import CasePaths
import Combine
import SwiftUI

// wrapper для run функции, This signature is what allows us to hand over control to the function we are invoking so that they can give us values back when they are ready, rather than demanding a value immediately.
struct Parallel<A> {
    let run: (@escaping (A) -> Void) -> Void
}

// называется Effect, потому что помогает избежать side effects (описание смотреть в PrimeTime.playground в этом проекте)
// не все эффекты производят Action, поэтому Action опционален
//public typealias Effect<Action> = () -> Action?
// использумя замыкание, effect будет решать когда он готов вернуть Action
//public typealias Effect<Action> = (@escaping (Action) -> Void) -> Void
//public struct Effect<A> {
//    public let run: (@escaping (A) -> Void) -> Void
//    public init(run: @escaping (@escaping (A) -> Void) -> Void) {
//        self.run = run
//    }
//
//    public func map<B> (_ f: @escaping (A) -> B) -> Effect<B> {
//        return Effect<B> { callback in self.run { a in callback(f(a)) } }
//    }
//}

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

// нужно чтобы возвращал массив эффектов, чтобы можно было использовать функцию combine
public typealias Reducer<Value, Action, Environment> = (inout Value, Action, Environment) -> [Effect<Action>]
// it's also a valid way of defining Reducer:
//public typealias Reducer<Value, Action, Environment> = (inout Value, Action) -> (Environment) -> [Effect<Action>]

public func combine<Value, Action, Environment>(
    _ reducers: Reducer<Value, Action, Environment>...
) -> Reducer<Value, Action, Environment> {
    return { value, action, environment in
        // call each reducer with a value and action
        let effects = reducers.flatMap { $0(&value, action, environment) }
        return effects
//        return { () -> Action? in
//            var finalAction: Action?
//            for effect in effects {
//                let action = effect()
//                if let action = action {
//                    finalAction = action
//                }
//            }
//            return finalAction
//        }
    }
}

//struct CasePath<Root, Value> {
//    let extract: (Root) -> Value?
//    let embed: (Value) -> Root
//}

public func pullback<LocalValue, GlobalValue, LocalAction, GlobalAction, LocalEnvironment, GlobalEnvironment>(
    _ reducer: @escaping Reducer<LocalValue, LocalAction, LocalEnvironment>,
    value: WritableKeyPath<GlobalValue, LocalValue>,
    action: CasePath<GlobalAction, LocalAction>,
    environment: @escaping (GlobalEnvironment) -> LocalEnvironment
) -> Reducer<GlobalValue, GlobalAction, GlobalEnvironment> {
    return { globalValue, globalAction, globalEnvironment in
        guard let localAction = action.extract(from: globalAction) else { return [] }
        let localEffects = reducer(&globalValue[keyPath: value], localAction, environment(globalEnvironment))
        
        return localEffects.map { localEffect in
            localEffect.map(action.embed)
                .eraseToEffect()
        }
    }
}

public func logging<Value, Action, Environment>(
    _ reducer: @escaping Reducer<Value, Action, Environment>
) -> Reducer<Value, Action, Environment> {
    return { value, action, environment in
        let effects = reducer(&value, action, environment)
        // inout параметр не может быть captured escaping замыканием, для этого создаем newValue
        let newValue = value
        // ignore the callcback
        return [.fireAndForget {
            print("Action: \(action)")
            print("Value:")
            dump(newValue)
            print("---")
        }] + effects
    }
}

// the store as an entire concept has very little to do with the environment. Users of a Store only care about getting state values out of it and sending actions to it. They never access the environment or even need to know about the environment that is being used under the hood. That's why we use Any and only in the init we use Environment
public final class Store<Value, Action>: ObservableObject {
    private let reducer: Reducer<Value, Action, Any>
    private let environment: Any
    // private(set) чтобы нельзя было менять это значение кроме как через метод  send(_ action: Action)
    @Published public private(set) var value: Value
    private var viewCancellable: Cancellable?
    private var effectCancellables: Set<AnyCancellable> = []
    
    // we actually cares about Environment in the initialization, that's why we use any in the Store, and Environement in the init
    public init<Environment>(
        initialValue: Value,
        reducer: @escaping Reducer<Value, Action, Environment>,
        environment: Environment
    ) {
        self.reducer = { value, action, environment in
            reducer(&value, action, environment as! Environment)
        }
        self.value = initialValue
        self.environment = environment
    }
    
    public func send(_ action: Action) {
        let effects = self.reducer(&self.value, action, self.environment)
        effects.forEach { effect in
            // Inside this receiveCompletion we could try to remove the cancellable from the array, but we don’t actually have access to it here. We have a bit of a chicken-and-egg problem, where the cancellable is created by calling sink but we need access to the cancellable from inside one of the closures that defines the sink.
            // To work around this we need to extract out the cancellable into an implicitly unwrapped optional, which allows us to get a variable for a type before it holds a value, and then later we get to assign the variable.
            var effectCancellable: AnyCancellable?
            var didComplete = false
            effectCancellable = effect.sink(
                receiveCompletion: { [weak self] _ in
                    didComplete = true
                    // мы можем попасть сюда до того как effectCancellable присвоется возврат sink похоже, поэтому нельзя использовать force unwrap
                    guard let effectCancellable else { return }
                    self?.effectCancellables.remove(effectCancellable)
                },
                receiveValue: self.send
            )
            // insert the effectCancellable into the set if the publisher did not complete immediately
            if !didComplete, let effectCancellable {
                self.effectCancellables.insert(effectCancellable)
            }
        }
    }
    
    // посмотреть локальное состояние
    public func view<LocalValue, LocalAction>(
        value toLocalValue: @escaping (Value) -> LocalValue,
        action toGlobalAction: @escaping (LocalAction) -> Action
    ) -> Store<LocalValue, LocalAction> {
        let localStore = Store<LocalValue, LocalAction>(
            initialValue: toLocalValue(self.value),
            reducer: { localValue, localAction, _ in
                self.send(toGlobalAction(localAction))
                localValue = toLocalValue(self.value)
                return []
            },
            environment: self.environment
        )
        // обновляем данные в localStore, когда делаем send в globalStore
        localStore.viewCancellable = self.$value.sink { [weak localStore] newValue in
            localStore?.value = toLocalValue(newValue)
        }
        return localStore
    }
}
