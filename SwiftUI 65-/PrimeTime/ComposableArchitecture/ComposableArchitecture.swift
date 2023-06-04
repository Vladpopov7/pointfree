import CasePaths
import Combine
import SwiftUI

// wrapper for the "run" function, This signature is what allows us to hand over control to the function we are invoking so that they can give us values back when they are ready, rather than demanding a value immediately.
//struct Parallel<A> {
//    let run: (@escaping (A) -> Void) -> Void
//}


// reducers take a current piece of state and combines it with an action in order to get the new updated state.
// we need to return an array of effects so that we can use the "combine" function
public typealias Reducer<Value, Action, Environment> = (inout Value, Action, Environment) -> [Effect<Action>]

// combine reducers into one Reducer
public func combine<Value, Action, Environment>(
    _ reducers: Reducer<Value, Action, Environment>...
) -> Reducer<Value, Action, Environment> {
    return { value, action, environment in
        // call each reducer with a value and action
        let effects = reducers.flatMap { $0(&value, action, environment) }
        return effects
    }
}

// "pullback" transforms a reducer on local state into one on global state
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

// logging without any side effects
public func logging<Value, Action, Environment>(
    _ reducer: @escaping Reducer<Value, Action, Environment>
) -> Reducer<Value, Action, Environment> {
    return { value, action, environment in
        let effects = reducer(&value, action, environment)
        // inout parameter cannot be captured by an escaping closure, that's why we create a "newValue"
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

// ObservableObject - This protocol utilizes an objectWillChange property of ObservableObjectPublisher, which is pinged before (not after) any mutations are made to your model
// let objectDidChange = ObservableObjectPublisher()
// This boilerplate is also not necessary, as the ObservableObject protocol will synthesize a default publisher for you automatically.
public final class ViewStore<Value, Action>: ObservableObject {
    @Published public fileprivate(set) var value: Value
    fileprivate var cancellable: Cancellable?
    public let send: (Action) -> Void
    
    public init(
        initialValue value: Value,
        send: @escaping (Action) -> Void
    ) {
        self.value = value
        self.send = send
    }
}

extension Store where Value: Equatable {
    public var view: ViewStore<Value, Action> {
        self.view(removeDuplicates: ==)
    }
}

extension Store {
    public func view(
        removeDuplicates predicate: @escaping (Value, Value) -> Bool
    ) -> ViewStore<Value, Action> {
        let viewStore = ViewStore(
            initialValue: self.value,
            send: self.send
        )
        
        // subscribe to store changes and replay those changes to ViewStore
        viewStore.cancellable = self.$value
            .removeDuplicates(by: predicate)
            .sink(receiveValue: { [weak viewStore] value in
                viewStore?.value = value
            })
        
        return viewStore
    }
}

// the store as an entire concept has very little to do with the environment. Users of a Store only care about getting state values out of it and sending actions to it. They never access the environment or even need to know about the environment that is being used under the hood. That's why we use Any and only in the init we use Environment
public final class Store<Value, Action> /*: ObservableObject*/ {
    private let reducer: Reducer<Value, Action, Any>
    private let environment: Any
    @Published private var value: Value
    private var viewCancellable: Cancellable?
    private var effectCancellables: [UUID: AnyCancellable] = [:]
    
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
            var didComplete = false
            let uuid = UUID()
            let effectCancellable = effect.sink(
                receiveCompletion: { [weak self] _ in
                    didComplete = true
                    self?.effectCancellables[uuid] = nil
                },
                receiveValue: { [weak self] in self?.send($0) }
            )
            if !didComplete {
                self.effectCancellables[uuid] = effectCancellable
            }
        }
    }
    
    // scope the local store
    public func scope<LocalValue, LocalAction>(
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
        // update data in localStorage when we send to global Store
        localStore.viewCancellable = self.$value
            .map(toLocalValue)
            .sink { [weak localStore] newValue in
                localStore?.value = newValue
            }
        return localStore
    }
}
