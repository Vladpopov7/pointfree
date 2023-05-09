import ComposableArchitecture
import SwiftUI

// this code has no access to global state or global user action. Copletely isolated from our entire application
public enum FavoritePrimesAction: Equatable {
    case deleteFavoritePrimes(IndexSet)
    case loadButtonTapped
    case loadedFavoritePrimes([Int])
    case saveButtonTapped
}

public func favoritePrimesReducer(
    state: inout [Int],
    action: FavoritePrimesAction,
    environment: FavoritePrimesEnvironment
) -> [Effect<FavoritePrimesAction>] {
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
        return [
            environment.save("favorite-primes.json", try! JSONEncoder().encode(state))
            // map from Effect<Never> to Effect<FavoritePrimesAction> (upcasting to the type), но при этом FavoritePrimesAction будет как Never, т.е. он не будет инициализироваться видимо
                .fireAndForget()
//            saveEffect(favoritePrimes: state)
        ]
        
    case .loadButtonTapped:
        return [
            environment.load("favorite-primes.json")
                .compactMap { $0 }
                .decode(type: [Int].self, decoder: JSONDecoder())
                .catch { error in Empty(completeImmediately: true) }
                .map(FavoritePrimesAction.loadedFavoritePrimes)
            // just for unit-tests example
//                .merge(with: Just(FavoritePrimesAction.loadedFavoritePrimes([2, 31])))
                .eraseToEffect()
//            loadEffect
//                .compactMap { $0 }
//                .eraseToEffect()
        ]
    }
}

// (Never) -> A

import Combine

extension Publisher where Output == Never, Failure == Never {
    func fireAndForget<A>() -> Effect<A> {
        return self.map(absurd).eraseToEffect()
    }
}

func absurd<A>(_ never: Never) -> A {
    // never не имеет кейсов, но так как компилятор стал умнее, мы можем даже switch не делать по пустому enum
//    switch never {}
}

public struct FileClient {
    var load: (String) -> Effect<Data?>
    var save: (String, Data) -> Effect<Never>
}

extension FileClient {
    public static let live = FileClient(
        load: { fileName -> Effect<Data?> in
            .sync {
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let documentUrl = URL(fileURLWithPath: documentsPath)
                let favoritePrimesUrl = documentUrl.appendingPathComponent(fileName)
                return try? Data(contentsOf: favoritePrimesUrl)
            }
        },
        save: { fileName, data in
            return .fireAndForget {
                // сам reducer не производит side effect, так как мы выполняем действия сохранения на диск внутри return функции Effect
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let documentUrl = URL(fileURLWithPath: documentsPath)
                let favoritePrimesUrl = documentUrl.appendingPathComponent(fileName)
                try! data.write(to: favoritePrimesUrl)
            }
        }
    )
}

// Dependency injection:
//public struct FavoritePrimesEnvironment {
//    var fileClient: FileClient
//}
public typealias FavoritePrimesEnvironment = FileClient
// we can extend in the future like this:
//public typealias FavoritePrimesEnvironment = (fileClient: FileClient, someOther: SomeOther, etc...)

//extension FavoritePrimesEnvironment {
//    public static let live = FavoritePrimesEnvironment(fileClient: .live)
//}

// we don't need global environment here, because we use environment parameter
//var Current = FavoritePrimesEnvironment.live

#if DEBUG
//extension FavoritePrimesEnvironment {
extension FileClient {
    static let mock = FileClient(
        load: { _ in Effect<Data?>.sync {
            try! JSONEncoder().encode ([2, 31])
        } },
        save: { _, _ in .fireAndForget {} }
    )
}
#endif

// Dependency injection:
//struct Environment {
//    var date: () -> Date
//}
//
//extension Environment {
//    static let live = Environment(date: Date.init)
//}
//
//extension Environment {
//    static let mock = Environment(date: { Date.init(timeIntervalSince1970: 1234567890) })
//}
//
////Current = .mock
//
//struct GitHubClient {
//    var fetchRepos: (@escaping (Result<[Repo], Error>) -> Void) -> Void
//    struct Repo: Decodable {
//        var archived: Bool
//        var description: String?
//        var htmlUrl: URL
//        var name: String
//        var pushedAt: Date?
//    }
//}
//
//#if DEBUG
//var Current = Environment.live
//#else
//let Current = Environment.live
//#endif

//private func saveEffect(favoritePrimes: [Int]) -> Effect<FavoritePrimesAction> {
//    return .fireAndForget {
////        Current.date()
//        // сам reducer не производит side effect, так как мы выполняем действия сохранения на диск внутри return функции Effect
//        let data = try! JSONEncoder().encode(favoritePrimes)
//        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
//        let documentUrl = URL(fileURLWithPath: documentsPath)
//        let favoritePrimesUrl = documentUrl.appendingPathComponent("favorite-primes.json")
//        try! data.write(to: favoritePrimesUrl)
//    }
//}

//private let loadEffect = Effect<FavoritePrimesAction?>.sync {
//    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
//    let documentUrl = URL(fileURLWithPath: documentsPath)
//    let favoritePrimesUrl = documentUrl.appendingPathComponent("favorite-primes.json")
//    guard
//        let data = try? Data(contentsOf: favoritePrimesUrl),
//        let favoritePrimes = try? JSONDecoder().decode([Int].self, from: data)
//    else { return nil }
//    // action loadButtonTapped производит другое action .loadedFavoritePrimes(favoritePrimes), поэтому отправляем его через callback
//    return .loadedFavoritePrimes(favoritePrimes)
//    // “unidirectional data flow.” Data is only ever mutated in one single way: an action comes into the reducer which allows the reducer to mutate the state. If you want to mutate the state via some side effect work, you have no choice but to construct a new action that can then be fed back into the reducer (в нашем случае это .loadedFavoritePrimes(favoritePrimes)), which only then gives you the ability to mutate.
//}

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
