import ComposableArchitecture
@testable import Counter
import PlaygroundSupport
import SwiftUI

// we can use separate screens as if we don't have a shared(common) state for the whole app, i.e. you can start migrating from UIKit to SwiftUI from small screens
PlaygroundPage.current.setLiveView(
    CounterView(
        store: Store(
            initialValue: CounterFeatureState(
                alertNthPrime: nil,
                count: 0,
                favoritePrimes: [],
                isNthPrimeRequestInFlight: false
            ),
            reducer: logging(counterViewReducer),
            environment: Counter.nthPrime
        )
    )
)
