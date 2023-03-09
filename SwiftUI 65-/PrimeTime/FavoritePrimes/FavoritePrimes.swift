import ComposableArchitecture
import SwiftUI

// this code has no access to global state or global user action. Copletely isolated from our entire application
public enum FavoritePrimesAction {
    case deleteFavoritePrimes(IndexSet)
    case loadButtonTapped
    case loadedFavoritePrimes([Int])
    case saveButtonTapped
}

public func favoritePrimesReducer(state: inout [Int], action: FavoritePrimesAction) -> [Effect<FavoritePrimesAction>] {
    switch action {
    case let .deleteFavoritePrimes(indexSet):
        for index in indexSet {
            state.remove(at: index)
        }
        return []
        
    case let .loadedFavoritePrimes(favoritePrimes):
        state = favoritePrimes
        return []

    case .saveButtonTapped:
        // избегаем ошибки @escaping closure captures 'inout' parameter 'state' создавая копию state, но это больше не нужно так как создали функцию saveEffect и она не принимает inout параметр
//        let state = state
        return [saveEffect(favoritePrimes: state)]
        
    case .loadButtonTapped:
        return [
            loadEffect
                .compactMap { $0 }
                .eraseToEffect()
        ]
    }
}

private func saveEffect(favoritePrimes: [Int]) -> Effect<FavoritePrimesAction> {
    return .fireAndForget {
        // сам reducer не производит side effect, так как мы выполняем действия сохранения на диск внутри return функции Effect
        let data = try! JSONEncoder().encode(favoritePrimes)
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let documentUrl = URL(fileURLWithPath: documentsPath)
        let favoritePrimesUrl = documentUrl.appendingPathComponent("favorite-primes.json")
        try! data.write(to: favoritePrimesUrl)
    }
}

import Combine

extension Effect {
    static func sync(work: @escaping () -> Output) -> Effect {
        // we don't want this to be eager effect, that's why we use Deferred
        return Deferred {
            Just(work())
        }.eraseToEffect()
    }
}

private let loadEffect = Effect<FavoritePrimesAction?>.sync {
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    let documentUrl = URL(fileURLWithPath: documentsPath)
    let favoritePrimesUrl = documentUrl.appendingPathComponent("favorite-primes.json")
    guard
        let data = try? Data(contentsOf: favoritePrimesUrl),
        let favoritePrimes = try? JSONDecoder().decode([Int].self, from: data)
    else { return nil }
    // action loadButtonTapped производит другое action .loadedFavoritePrimes(favoritePrimes), поэтому отправляем его через callback
    return .loadedFavoritePrimes(favoritePrimes)
    // “unidirectional data flow.” Data is only ever mutated in one single way: an action comes into the reducer which allows the reducer to mutate the state. If you want to mutate the state via some side effect work, you have no choice but to construct a new action that can then be fed back into the reducer (в нашем случае это .loadedFavoritePrimes(favoritePrimes)), which only then gives you the ability to mutate.
}

public struct FavoritePrimesView: View {
    @ObservedObject var store: Store<[Int], FavoritePrimesAction>
    
    public init(store: Store<[Int], FavoritePrimesAction>) {
        self.store = store
    }

    public var body: some View {
        List {
            ForEach(self.store.value, id: \.self) { prime in
                Text("\(prime)")
            }
            .onDelete { indexSet in
                self.store.send(.deleteFavoritePrimes(indexSet))
            }
        }
        .navigationBarTitle(Text("Favorite Primes"))
        .navigationBarItems(
            trailing: HStack {
                Button("Save") {
                    self.store.send(.saveButtonTapped)
//                    let data = try! JSONEncoder().encode(self.store.value)
//                    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
//                    let documentUrl = URL(fileURLWithPath: documentsPath)
//                    let favoritePrimesUrl = documentUrl.appendingPathComponent("favorite-primes.json")
//                    try! data.write(to: favoritePrimesUrl)
                }
                Button("Load") {
                    self.store.send(.loadButtonTapped)
                    // вызывать весь код загрузки из памяти здесь и затем отправлять новое действие .loadedFAvoritePrimes это side effect, поэтому это перенесено в loadButtonTapped и уже там внутри вернется и вызовется действие loadedFavoritePrimes и это называется unidirectional data flow - Data is only ever mutated in one single way: an action comes into the reducer which allows the reducer to mutate the state. If you want to mutate the state via some side effect work, you have no choice but to construct a new action that can then be fed back into the reducer, which only then gives you the ability to mutate.
                    
//                    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
//                    let documentUrl = URL(fileURLWithPath: documentsPath)
//                    let favoritePrimesUrl = documentUrl.appendingPathComponent("favorite-primes.json")
//                    guard
//                        let data = try? Data(contentsOf: favoritePrimesUrl),
//                        let favoritePrimes = try? JSONDecoder().decode([Int].self, from: data)
//                    else { return }
//                    self.store.send(.loadedFavoritePrimes(favoritePrimes))
                }
            }
        )
    }
}
