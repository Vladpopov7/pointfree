import CasePaths
import Combine
import SwiftUI

// wrapper for the "run" function, This signature is what allows us to hand over control to the function we are invoking so that they can give us values back when they are ready, rather than demanding a value immediately.
//struct Parallel<A> {
//    let run: (@escaping (A) -> Void) -> Void
//}


// reducers take a current piece of state and combines it with an action in order to get the new updated state. The reducer can mutate some app state, which is captured by the Value generic, given an action. Environment holds all the feature dependencies like API clients, file clients, etc.
// we need to return an array of effects, that will be run after our business logic has been executed. That's what allows us to interact with the outside world and feed informatino from the outside back into our application.
//public typealias Reducer<Value, Action, Environment> = (inout Value, Action, Environment) -> [Effect<Action>]
public struct Reducer<Value, Action, Environment> {
    let reducer: (inout Value, Action, Environment) -> [Effect<Action>]
    
    public init(_ reducer: @escaping (inout Value, Action, Environment) -> [Effect<Action>]) {
        self.reducer = reducer
    }
}

extension Reducer {
    // Swift 5.2: “callable values.”
    public func callAsFunction(_ value: inout Value, _ action: Action, _ environment: Environment) -> [Effect<Action>] {
        self.reducer(&value, action, environment)
    }
}

extension Reducer {
    // combine reducers into one Reducer
    public static func combine(_ reducers: Reducer...) -> Reducer {
        .init { value, action, environment in
            // call each reducer with a value and action
            let effects = reducers.flatMap {
                // Swift 5.2: “callable values.” If a type defines a callAsFunction method, then it can be called directly, as if it were a function.
                $0(&value, action, environment)
            }
            return effects
        }
    }
}

extension Reducer {
    // "pullback" transforms a reducer on a local state into one on a global state
    public func pullback<GlobalValue, GlobalAction, GlobalEnvironment>(
        value: WritableKeyPath<GlobalValue, Value>,
        action: CasePath<GlobalAction, Action>,
        environment: @escaping (GlobalEnvironment) -> Environment
    ) -> Reducer<GlobalValue, GlobalAction, GlobalEnvironment> {
        .init { globalValue, globalAction, globalEnvironment in
            guard let localAction = action.extract(from: globalAction) else { return [] }
            let localEffects = self(&globalValue[keyPath: value], localAction, environment(globalEnvironment))
            
            return localEffects.map { localEffect in
                localEffect.map(action.embed)
                    .eraseToEffect()
            }
        }
    }
}

extension Reducer {
    // logging without any side effects
    public func logging(
        printer: @escaping (Environment) -> (String) -> Void = { _ in { print($0) } }
    ) -> Reducer {
        .init { value, action, environment in
            let effects = self(&value, action, environment)
            // inout parameter cannot be captured by an escaping closure, that's why we create a "newValue"
            let newValue = value
            let print = printer(environment)

            return [.fireAndForget {
                print("Action: \(action)")
                print("Value:")
                
                var dumpedNewValue = ""
                dump(newValue, to: &dumpedNewValue)
                print(dumpedNewValue)
                print("---")
            }] + effects
        }
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
        reducer: Reducer<Value, Action, Environment>,
        environment: Environment
    ) {
        self.reducer = .init { value, action, environment in
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
    
    // scope can transform stores on global state and global actions into stores on more local state and local actions. This operation is exactly what allowed us to isolate our app’s views into their own modules.
    public func scope<LocalValue, LocalAction>(
        value toLocalValue: @escaping (Value) -> LocalValue,
        action toGlobalAction: @escaping (LocalAction) -> Action
    ) -> Store<LocalValue, LocalAction> {
        let localStore = Store<LocalValue, LocalAction>(
            initialValue: toLocalValue(self.value),
            reducer: .init { localValue, localAction, _ in
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
