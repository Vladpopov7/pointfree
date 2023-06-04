#if os(iOS)
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
        let isPrimeModalShown: Bool
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
        case primeModalDismissed
        case doubleTap
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
                    .disabled(self.viewStore.value.isDecrementButtonDisabled)
                Text("\(self.viewStore.value.count)")
                Button("+") { self.viewStore.send(.incrTapped) }
                    .disabled(self.viewStore.value.isIncrementButtonDisabled)
            }
            Button("Is this prime?") { self.viewStore.send(.isPrimeButtonTapped) }
            Button(self.viewStore.value.nthPrimeButtonTitle) {
                self.viewStore.send(.nthPrimeButtonTapped)
            }
                .disabled(self.viewStore.value.isNthPrimeButtonDisabled)
        }
        .font(.title)
        .navigationBarTitle("Counter demo")
        // since we don't store "isPresented" in @State anymore, so we use .constant
//        .sheet(isPresented: self.$isPrimeModalShown) {
        .sheet(
            isPresented: .constant(self.viewStore.value.isPrimeModalShown),
            onDismiss: { self.viewStore.send(.primeModalDismissed) }
        ) {
            IsPrimeModalView(
                store: self.store
                    .scope(
                        value: { ($0.count, $0.favoritePrimes) },
                        action: { .primeModal($0) }
                    )
            )
        }
        // will be shown when alertNthPrime is not nil
        .alert(
            // since we store alertNthPrime in store as a simple property, and we need to pass Binding, we need to create Binding ourselves here
//            item: Binding(get: { self.viewStore.value.alertNthPrime }, set: { _ in })
            // but it's even easier to create a Binding (which doesn't have a setter) like so:
            item: .constant(self.viewStore.value.alertNthPrime)
        ) { alert in
            Alert(
                title: Text(alert.title),
                dismissButton: Alert.Button.default(Text("Ok")) {
                    self.viewStore.send(.alertDismissButtonTapped)
                }
            )
        }
        // to make tap gesture working in the white areay
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(Color.white)
        .onTapGesture(count: 2) {
            self.viewStore.send(.doubleTap)
        }
    }
}

extension CounterView.State {
    init(counterFeatureState: CounterFeatureState) {
        self.alertNthPrime = counterFeatureState.alertNthPrime
        self.count = counterFeatureState.count
        self.isNthPrimeButtonDisabled = counterFeatureState.isNthPrimeRequestInFlight
        // for iOS it is a "modal", for agnostic state it is a common name "Detail" for iOS and macOS
        self.isPrimeModalShown = counterFeatureState.isPrimeDetailShown
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
        case .primeModalDismissed:
            self = .counter(.primeDetailDismissed)
        case .doubleTap:
            self = .counter(.requestNthPrime)
        }
    }
}
#endif
