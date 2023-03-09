//
//  ContentView.swift
//  PrimeTime
//
//  Created by Vladislav Popov on 27/02/2023.
//

import Combine
import ComposableArchitecture
import Counter
import FavoritePrimes
import SwiftUI

// BindableObject is deprecated
//class AppState: BindableObject {
//    var count = 0 {
//        didSet {
//            // так мы уведомим всех подписчиков, кто использует AppState
//            self.didChange.send()
//        }
//    }
//
//    var didChange = PassthroughSubject<Void, Never>
//}

// ObservableObject - This protocol utilizes an objectWillChange property of ObservableObjectPublisher, which is pinged before (not after) any mutations are made to your model
// let objectDidChange = ObservableObjectPublisher()
// This boilerplate is also not necessary, as the ObservableObject protocol will synthesize a default publisher for you automatically.
struct AppState {
//    With Xcode 11 beta 5 and later, willSet should be used instead of didSet:
//    var count = 0 {
//      willSet {
//        self.objectWillChange.send()
//      }
//    }
//    Or you can remove this boilerplate entirely by using a @Published property wrapper:
    var count = 0
    
//    var favoritePrimes: [Int] = [] {
//        // notify anyone who use this AppState, that the state will be changed
//        willSet { self.objectWillChange.send() }
//    }
    // можно не использовать willSet а просто сделать @Published проперти и оно само уведомит всех кто использует AppState
    var favoritePrimes: [Int] = []
    // мы не можем объединить count и favoritePrimes в одно проперти primeModal, потому что эти проперти нужны и другим экранам, и это было бы неправильно получать их через проперти primeModal
    // var primeModal: PrimeModalState
    var loggedInUser: User?
    var activityFeed: [Activity] = []
    var alertNthPrime: PrimeAlert? = nil
    var isNthPrimeButtonDisabled: Bool = false
    
    struct Activity {
        let timestamp: Date
        let type: ActivityType
        
        enum ActivityType {
            case addedFavoritePrime(Int)
            case removedFavoritePrime(Int)
        }
    }
    
    struct User {
        let id: Int
        let name: String
        let bio: String
    }
}

// this action nests other actions for different screens
enum AppAction {
//    case counter(CounterAction)
//    case primeModal(PrimeModalAction)
    case counterView(CounterViewAction)
    case favoritePrimes(FavoritePrimesAction)
    
    // это как keyPath, только для Actions (так как это enum)
    var favoritePrimes: FavoritePrimesAction? {
        get {
            guard case let .favoritePrimes(value) = self else { return nil }
            return value
        }
        set {
            guard case .favoritePrimes = self, let newValue = newValue else { return }
            self = .favoritePrimes(newValue)
        }
    }
    
    var counterView: CounterViewAction? {
        get {
            guard case let .counterView(value) = self else { return nil }
            return value
        }
        set {
            guard case .counterView = self, let newValue = newValue else { return }
            self = .counterView(newValue)
        }
    }
}

struct _KeyPath<Root, Value> {
    let get: (Root) -> Value
    let set: (inout Root, Value) -> Void
}

struct EnumKeyPath<Root, Value> {
    let embed: (Value) -> Root
    let extract: (Root) -> Value?
}
// \AppAction.counter // EnumKeyPath<AppAction, CounterAppAction>

// higher order function
func activityFeed(
    _ reducer: @escaping Reducer<AppState, AppAction>
) -> Reducer<AppState, AppAction> {
    
    return { state, action in
        switch action {
        case .counterView(.counter),
                .favoritePrimes(.loadedFavoritePrimes),
                .favoritePrimes(.loadButtonTapped),
                .favoritePrimes(.saveButtonTapped):
            break
            
        case .counterView(.primeModal(.removeFavoritePrimeTapped)):
            state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))
            
        case .counterView(.primeModal(.saveFavoritePrimeTapped)):
            state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))
            
        case let .favoritePrimes(.deleteFavoritePrimes(indexSet)):
            for index in indexSet {
                state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.favoritePrimes[index])))
            }
        }

        return reducer(&state, action)
    }
}

extension AppState {
    var counterView: CounterViewState {
        get {
            CounterViewState(
                alertNthPrime: self.alertNthPrime,
                count: self.count,
                favoritePrimes: self.favoritePrimes,
                isNthPrimeButtonDisabled: self.isNthPrimeButtonDisabled
             )
        }
        set {
            self.alertNthPrime = newValue.alertNthPrime
            self.count = newValue.count
            self.favoritePrimes = newValue.favoritePrimes
            self.isNthPrimeButtonDisabled = newValue.isNthPrimeButtonDisabled
        }
    }
}

//let _appReducer: (inout AppState, AppAction) -> Void = combine(
let appReducer = combine(
    pullback(counterViewReducer, value: \AppState.counterView, action: \AppAction.counterView),
    pullback(favoritePrimesReducer, value: \.favoritePrimes, action: \.favoritePrimes)
)
// \.self represents the key path from AppState to AppState where the getter just returns self and the setter just replaces itself with the new value coming in. This pullback has not changed the app reducer at all, the _appReducer and the appReducer behave exactly the same.
//let appReducer = pullback(_appReducer, value: \.self, action: \.self)

var state = AppState()

struct ContentView: View {
    @ObservedObject var store: Store<AppState, AppAction>
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink(
                    "Counter demo",
                    destination: CounterView(
                        store: self.store
                            .view(
                                value: { $0.counterView },
                                action: { .counterView($0) }
                            )
                    )
                )
                NavigationLink(
                    "Favorite primes",
                    destination: FavoritePrimesView(
                        store: self.store.view(
                            value: { $0.favoritePrimes },
                            action: { .favoritePrimes($0) }
                        )
                    )
                )
            }
        }
        .navigationBarTitle("State management")
        // fix, to display UIHostingController
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            store: Store(
                initialValue: AppState(),
                reducer: with(
                    appReducer,
                    compose(
                        logging,
                        activityFeed
                    )
                )
            )
        )
    }
}
