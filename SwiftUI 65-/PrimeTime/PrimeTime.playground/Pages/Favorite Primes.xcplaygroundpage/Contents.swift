import ComposableArchitecture
@testable import FavoritePrimes
import PlaygroundSupport
import SwiftUI

Current = .mock
Current.fileClient.load = { _ in
    Effect.sync { try!
        JSONEncoder().encode(Array(1...100))
    }
}

PlaygroundPage.current.liveView = UIHostingController(
    rootView: NavigationView {
        FavoritePrimesView(
            store: Store<[Int], FavoritePrimesAction>(
                initialValue: [2, 3, 5, 7, 11],
                reducer: favoritePrimesReducer
            )
        )
    }
    // fix, to display UIHostingController
    .navigationViewStyle(StackNavigationViewStyle())
)

//func compute(_ x: Int) -> Int {
//    let computation =  x * x + 1
//    // print это side effect, side effects сложно тестировать:
//    print("Computed \(computation)")
//    return computation
//}
//
//// вот как можно избавиться от side effect, так же и для reducer'ов будем возвращать не Void а Effect
//func computeAndPrint(_ x: Int) -> (Int, [String]) {
//    let computation = x * x + 1
//    return (computation, ["Computed \(computation)"])
//}
