import ComposableArchitecture
@testable import Counter
import PlaygroundSupport
import SwiftUI

var environment = CounterEnvironment.mock
environment.nthPrime = { _ in
        .sync { 7236893748932 }
}

// мы можем использовать отдельные экраны, как-будто у нас нет общего состояния, т.е. можно начать мигрировать с UIKit на SwiftUI с мелких экранов\
// разбор экрана которые имеет modal экран и может управлять состоянием показа этого экрана (primeModal(PrimeModalAction) в CounterViewAction)
PlaygroundPage.current.liveView = UIHostingController(
  rootView: CounterView(
    store: Store<CounterViewState, CounterViewAction>(
      initialValue: CounterViewState(
        alertNthPrime: nil,
        count: 0,
        favoritePrimes: [],
        isNthPrimeButtonDisabled: false
      ),
      reducer:  logging(counterViewReducer),
      environment: environment
    )
  )
)
