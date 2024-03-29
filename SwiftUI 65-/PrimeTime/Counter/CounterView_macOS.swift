#if os(macOS)
import Combine
import ComposableArchitecture
import PrimeAlert
import PrimeModal
import SwiftUI

public struct CounterView: View {
    struct State: Equatable {
        let alertNthPrime: PrimeAlert?
        let count: Int
        let isNthPrimeButtonDisabled: Bool
        let isPrimePopoverShown: Bool
        let isIncrementButtonDisabled: Bool
        let isDecrementButtonDisabled: Bool
        let nthPrimeButtonTitle: String
    }
    
    // Actions related to view
    public enum Action {
        case decrTapped
        case incrTapped
        case nthPrimeButtonTapped
        case alertDismissButtonTapped
        case isPrimeButtonTapped
        case primePopoverDismissed
    }

    // to save the state we need to use @ObservedObject (deprecated @ObjectBinding)
    let store: Store<CounterFeatureState, CounterFeatureAction>
    @ObservedObject var viewStore: ViewStore<State, Action>
    
    public init(store: Store<CounterFeatureState, CounterFeatureAction>) {
        self.store = store
        self.viewStore = self.store
            .scope(
                value: State.init,
                action: CounterFeatureAction.init
            )
            .view
    }
    
    public var body: some View {
        return VStack {
            HStack {
                Button("-") { self.viewStore.send(.decrTapped) }
                    .disabled(self.viewStore.isDecrementButtonDisabled)
                Text("\(self.viewStore.count)")
                Button("+") { self.viewStore.send(.incrTapped) }
                    .disabled(self.viewStore.isIncrementButtonDisabled)
            }
            Button("Is this prime?") { self.viewStore.send(.isPrimeButtonTapped) }
            Button(self.viewStore.nthPrimeButtonTitle) {
                self.viewStore.send(.nthPrimeButtonTapped)
            }
                .disabled(self.viewStore.isNthPrimeButtonDisabled)
        }
        // since we don't store "isPresented" in @State anymore, so we use binding method from ViewStore
//        .sheet(isPresented: self.$isPrimeModalShown) {
        .sheet(
            isPresented: self.viewStore.binding(
                get: \.isPrimePopoverShown,
                send: .primePopoverDismissed
            )
        ) {
            IsPrimeModalView(
                store: self.store
                    .scope(
                        value: { ($0.count, $0.favoritePrimes) },
                        action: { .primeModal($0) }
                    )
            )
        }
        .alert(
            item: .constant(self.viewStore.alertNthPrime)
        ) { alert in
            Alert(
                title: Text(alert.title),
                dismissButton: Alert.Button.default(Text("Ok")) {
                    self.viewStore.send(.alertDismissButtonTapped)
                }
            )
        }
    }
}

extension CounterView.State {
    init(counterFeatureState: CounterFeatureState) {
        self.alertNthPrime = counterFeatureState.alertNthPrime
        self.count = counterFeatureState.count
        self.isNthPrimeButtonDisabled = counterFeatureState.isNthPrimeRequestInFlight
        // for macOS it is a "popover", for agnostic state it is a common name "Detail" for iOS and macOS
        self.isPrimePopoverShown = counterFeatureState.isPrimeDetailShown
        self.isIncrementButtonDisabled = counterFeatureState.isNthPrimeRequestInFlight
        self.isDecrementButtonDisabled = counterFeatureState.isNthPrimeRequestInFlight
        self.nthPrimeButtonTitle = "What is the \(ordinal(counterFeatureState.count)) prime?"
    }
}

extension CounterFeatureAction {
    init(action: CounterView.Action) {
        switch action {
        case .decrTapped:
            self = .counter(.decrTapped)
        case .incrTapped:
            self = .counter(.incrTapped)
        case .nthPrimeButtonTapped:
            self = .counter(.requestNthPrime)
        case .alertDismissButtonTapped:
            self = .counter(.alertDismissButtonTapped)
        case .isPrimeButtonTapped:
            self = .counter(.isPrimeButtonTapped)
        case .primePopoverDismissed:
            self = .counter(.primeDetailDismissed)
        }
    }
}
#endif
