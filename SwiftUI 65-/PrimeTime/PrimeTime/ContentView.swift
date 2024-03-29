//
//  ContentView.swift
//  PrimeTime
//
//  Created by Vladislav Popov on 27/02/2023.
//

import CasePaths
import Combine
import ComposableArchitecture
import Counter
import FavoritePrimes
import PrimeAlert
import SwiftUI

struct AppState: Equatable {
    // we can't combine count and favoritePrimes into one primeModal property, because other screens need these properties, and it would be wrong to get them through the primeModal property
    var count = 0
    var favoritePrimes: [Int] = []
    var loggedInUser: User?
    var activityFeed: [Activity] = []
    var alertNthPrime: PrimeAlert? = nil
    var isNthPrimeRequestInFlight: Bool = false
    var isPrimeDetailShown: Bool = false
    
    struct Activity: Equatable {
        let timestamp: Date
        let type: ActivityType
        
        enum ActivityType: Equatable {
            case addedFavoritePrime(Int)
            case removedFavoritePrime(Int)
        }
    }
    
    struct User: Equatable {
        let id: Int
        let name: String
        let bio: String
    }
}

// this action nests other actions for different screens
enum AppAction: Equatable {
    case counterView(CounterFeatureAction)
    case offlineCounterView(CounterFeatureAction)
    case favoritePrimes(FavoritePrimesAction)
}

extension AppState {
    var favoritePrimesState: FavoritePrimesState {
        get {
            (self.alertNthPrime, self.favoritePrimes)
        }
        set {
            (self.alertNthPrime, self.favoritePrimes) = newValue
        }
    }
    
    var counterView: CounterFeatureState {
        get {
            CounterFeatureState(
                alertNthPrime: self.alertNthPrime,
                count: self.count,
                favoritePrimes: self.favoritePrimes,
                isNthPrimeRequestInFlight: self.isNthPrimeRequestInFlight,
                isPrimeDetailShown: self.isPrimeDetailShown
             )
        }
        set {
            self.alertNthPrime = newValue.alertNthPrime
            self.count = newValue.count
            self.favoritePrimes = newValue.favoritePrimes
            self.isNthPrimeRequestInFlight = newValue.isNthPrimeRequestInFlight
            self.isPrimeDetailShown = newValue.isPrimeDetailShown
        }
    }
}

typealias AppEnvironment = (
    fileClient: FileClient,
    nthPrime: (Int) -> Effect<Int?>,
    offlineNthPrime: (Int) -> Effect<Int?>
)

// reducer takes a current piece of state and combines it with an action in order to get the new updated state.
let appReducer: Reducer<AppState, AppAction, AppEnvironment> = .combine(
    counterFeatureReducer.pullback(
        value: \AppState.counterView,
        action: /AppAction.counterView,
        environment: { $0.nthPrime }
    ),
    counterFeatureReducer.pullback(
        value: \AppState.counterView,
        action: /AppAction.offlineCounterView,
        environment: { $0.offlineNthPrime }
    ),
    favoritePrimesReducer.pullback(
        value: \.favoritePrimesState,
        action: /AppAction.favoritePrimes,
        environment: { ($0.fileClient, $0.nthPrime) }
    )
)

extension Reducer where Value == AppState, Action == AppAction, Environment == AppEnvironment {
    func activityFeed() -> Reducer {
        return .init { state, action, environment in
            switch action {
            case .counterView(.counter),
                    .offlineCounterView(.counter),
                    .favoritePrimes(.loadedFavoritePrimes),
                    .favoritePrimes(.loadButtonTapped),
                    .favoritePrimes(.saveButtonTapped),
                    .favoritePrimes(.primeButtonTapped),
                    .favoritePrimes(.nthPrimeResponse),
                    .favoritePrimes(.alertDismissButtonTapped):
                break
                
            case .counterView(.primeModal(.removeFavoritePrimeTapped)),
                    .offlineCounterView(.primeModal(.removeFavoritePrimeTapped)):
                state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))
                
            case .counterView(.primeModal(.saveFavoritePrimeTapped)),
                    .offlineCounterView(.primeModal(.saveFavoritePrimeTapped)):
                state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))
                
            case let .favoritePrimes(.deleteFavoritePrimes(indexSet)):
                for index in indexSet {
                    state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.favoritePrimes[index])))
                }
            }

            return self(&state, action, environment)
        }
    }
}

struct ContentView: View {
    let store: Store<AppState, AppAction>
    
    init(store: Store<AppState, AppAction>) {
        self.store = store
    }
    
    var body: some View {
        return NavigationView {
            List {
                // the same view (CounterView) can be used with different environments
                NavigationLink(
                    "Counter demo",
                    destination: CounterView(
                        store: self.store
                            .scope(
                                value: { $0.counterView },
                                action: { .counterView($0) }
                            )
                    )
                )
                NavigationLink(
                    "Offline counter demo",
                    destination: CounterView(
                        store: self.store
                            .scope(
                                value: { $0.counterView },
                                action: { .offlineCounterView($0) }
                            )
                    )
                )
                NavigationLink(
                    "Favorite primes",
                    destination: FavoritePrimesView(
                        store: self.store.scope(
                            value: { $0.favoritePrimesState },
                            action: { .favoritePrimes($0) }
                        )
                    )
                )
                
                ForEach(Array (1...500_000), id: \.self) { value in
                    Text("\(value)")
                }
            }
            .navigationBarTitle("State management")
            // fix, to display UIHostingController
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }
}
