import Combine
import ComposableArchitecture
import PrimeAlert
import SwiftUI

public typealias FavoritePrimesState = (
    alertNthPrime: PrimeAlert?,
    favoritePrimes: [Int]
)

// this code has no access to global state or global user action. Copletely isolated from our entire application
public enum FavoritePrimesAction: Equatable {
    case deleteFavoritePrimes(IndexSet)
    case loadButtonTapped
    case loadedFavoritePrimes([Int])
    case primeButtonTapped(Int)
    case saveButtonTapped
    case nthPrimeResponse(n: Int, prime: Int?)
    case alertDismissButtonTapped
}

// Dependency injection:
public typealias FavoritePrimesEnvironment = (
    fileClient: FileClient,
    nthPrime: (Int) -> Effect<Int?>
)

public let favoritePrimesReducer = Reducer<FavoritePrimesState, FavoritePrimesAction, FavoritePrimesEnvironment> { state, action, environment in
    switch action {
    case let .deleteFavoritePrimes(indexSet):
        for index in indexSet {
            state.favoritePrimes.remove(at: index)
        }
        return []
        
    case let .loadedFavoritePrimes(favoritePrimes):
        state.favoritePrimes = favoritePrimes
        return []

    case .saveButtonTapped:
        // avoid the error "@escaping closure captures 'inout' parameter 'state'" by creating a copy of the state, but this is no longer needed since we created the saveEffect function and it does not accept an inout parameter
//        let state = state
        return [
            environment.fileClient.save("favorite-primes.json", try! JSONEncoder().encode(state.favoritePrimes))
                .fireAndForget()
        ]
        
    case .loadButtonTapped:
        return [
            environment.fileClient.load("favorite-primes.json")
                .compactMap { $0 }
                .decode(type: [Int].self, decoder: JSONDecoder())
                .catch { error in Empty(completeImmediately: true) }
                .map(FavoritePrimesAction.loadedFavoritePrimes)
                .eraseToEffect()
        ]
    case let .primeButtonTapped(n):
        return [
            environment.nthPrime(n)
                .map { FavoritePrimesAction.nthPrimeResponse(n: n, prime: $0) }
                .receive(on: DispatchQueue.main)
                .eraseToEffect()
        ]
    case .nthPrimeResponse(n: let n, prime: let prime):
        state.alertNthPrime = prime.map { PrimeAlert(n: n, prime: $0) }
        return []
    case .alertDismissButtonTapped:
        state.alertNthPrime = nil
        return []
    }
}

public struct FavoritePrimesView: View {
    let store: Store<FavoritePrimesState, FavoritePrimesAction>
    @ObservedObject var viewStore: ViewStore<FavoritePrimesState, FavoritePrimesAction>
    
    public init(store: Store<FavoritePrimesState, FavoritePrimesAction>) {
        self.store = store
        self.viewStore = self.store.view(removeDuplicates: ==)
    }

    public var body: some View {
        return List {
            ForEach(self.viewStore.favoritePrimes, id: \.self) { prime in
                Button("\(prime)") {
                    self.viewStore.send(.primeButtonTapped(prime))
                }
            }
            .onDelete { indexSet in
                self.viewStore.send(.deleteFavoritePrimes(indexSet))
            }
        }
        .navigationBarTitle(Text("Favorite Primes"))
        .navigationBarItems(
            trailing: HStack {
                Button("Save") {
                    self.viewStore.send(.saveButtonTapped)
                }
                Button("Load") {
                    self.viewStore.send(.loadButtonTapped)
                    // calling all the loading code from memory here and then sending a new action .loadedFAvoritePrimes is a side effect, so these actions are moved to .loadButtonTapped and there inside it will return and the loadedFavoritePrimes action will be called and this is called "unidirectional data flow" - Data is only ever mutated in one single way: an action comes into the reducer which allows the reducer to mutate the state. If you want to mutate the state via some side effect work, you have no choice but to construct a new action that can then be fed back into the reducer, which only then gives you the ability to mutate.
                }
            }
        )
        .alert(
            item: self.viewStore.binding(
                get: \.alertNthPrime,
                send: .alertDismissButtonTapped
            )
        ) { primeAlert in
            Alert(title: Text(primeAlert.title))
        }
    }
}
