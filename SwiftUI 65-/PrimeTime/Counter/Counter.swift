import Combine
import ComposableArchitecture
import PrimeAlert
import PrimeModal
import SwiftUI

public enum CounterAction: Equatable {
    case decrTapped
    case incrTapped
    case nthPrimeButtonTapped
    case nthPrimeResponse(n: Int, prime: Int?)
    case alertDismissButtonTapped
    case isPrimeButtonTapped
    case primeModalDismissed
}

public typealias CounterState = (
    alertNthPrime: PrimeAlert?,
    count: Int,
    isNthPrimeButtonDisabled: Bool,
    isPrimeModalShown: Bool
)

public func counterReducer(
    state: inout CounterState,
    action: CounterAction,
    environment: CounterEnvironment
) -> [Effect<CounterAction>] {
    switch action {
    case .decrTapped:
        state.count -= 1
        let count = state.count
        return [
//            .fireAndForget {
//                print(count)
//            },
//            
//            // wait for 1 second every time we decrement and then increment, this functionality just for presentation
//            Just(CounterAction.incrTapped)
//                .delay(for: 1, scheduler: DispatchQueue.main)
//                .eraseToEffect()
        ]
        
    case .incrTapped:
        state.count += 1
        return []
        
    case .nthPrimeButtonTapped:
        state.isNthPrimeButtonDisabled = true
        let n = state.count
        return [
//            nthPrime(state.count)
            environment(state.count)
//                .map { CounterAction.nthPrimeResponse($0)}
                // так короче:
//                .map(CounterAction.nthPrimeResponse)
                .map { CounterAction.nthPrimeResponse(n: n, prime: $0) }
                .receive(on: DispatchQueue.main)
                .eraseToEffect()

//            Effect { callback in
//                // лучше сделать без semaphore
//                nthPrime(count) { prime in
//                    // обернули в main чтобы на SwiftUI было в main потоке (URLSession data tasks execute their completion blocks on background threads by default)
//                    DispatchQueue.main.async {
//                        // возвращаем асинхронно action nthPrimeResponse через callback
//                        callback(.nthPrimeResponse(prime))
//                    }
//                }
//
//                //            // пример с асинхронным действием, мы ждем когда получим ответ от nthPrime через semaphor, и делаем return c полученным значением
//                //            var p: Int?
//                //            let sema = DispatchSemaphore(value: 0)
//                //            nthPrime(count) { prime in
//                //                p = prime
//                //                sema.signal()
//                //            }
//                //            sema.wait()
//                //            return .nthPrimeResponse(p)
//            }
        ]
    case let .nthPrimeResponse(n, prime):
        state.alertNthPrime = prime.map { PrimeAlert(n: n, prime: $0) }
        state.isNthPrimeButtonDisabled = false
        return []
        
    case .alertDismissButtonTapped:
        state.alertNthPrime = nil
        return []
        
    case .isPrimeButtonTapped:
        state.isPrimeModalShown = true
        return []
        
    case .primeModalDismissed:
        state.isPrimeModalShown = false
        return []
    }
}

//public struct CounterEnvironment {
//    var nthPrime: (Int) -> Effect<Int?>
//}
public typealias CounterEnvironment = (Int) -> Effect<Int?>

//extension CounterEnvironment {
//    public static let live = CounterEnvironment(nthPrime: Counter.nthPrime)
//}

//var Current = CounterEnvironment.live

//extension CounterEnvironment {
//    static let mock = CounterEnvironment(nthPrime: { _ in .sync { 17 }})
//}

import CasePaths

// комбинация двух pullback для экрана который может показывать modal экран
public let counterViewReducer: Reducer<CounterViewState, CounterViewAction, CounterEnvironment> = combine(
    pullback(
        counterReducer,
        value: \CounterViewState.counter,
        action: /CounterViewAction.counter,
        environment: { $0 }
    ),
    pullback(
        primeModalReducer,
        value: \.primeModal,
        action: /CounterViewAction.primeModal,
        // Void environment
        environment: { _ in () }
    )
)

public struct CounterViewState: Equatable {
    public var alertNthPrime: PrimeAlert?
    public var count: Int
    public var favoritePrimes: [Int]
    public var isNthPrimeButtonDisabled: Bool
    public var isPrimeModalShown: Bool
    
    public init(
        alertNthPrime: PrimeAlert? = nil,
        count: Int = 0,
        favoritePrimes: [Int] = [],
        isNthPrimeButtonDisabled: Bool = false,
        isPrimeModalShown: Bool = false
    ) {
        self.alertNthPrime = alertNthPrime
        self.count = count
        self.favoritePrimes = favoritePrimes
        self.isNthPrimeButtonDisabled = isNthPrimeButtonDisabled
        self.isPrimeModalShown = isPrimeModalShown
    }
    
    var counter: CounterState {
        get { (self.alertNthPrime, self.count, self.isNthPrimeButtonDisabled, self.isPrimeModalShown) }
        set { (self.alertNthPrime, self.count, self.isNthPrimeButtonDisabled, self.isPrimeModalShown) = newValue }
    }
    
    var primeModal: PrimeModalState {
        get { (self.count, self.favoritePrimes) }
        set { (self.count, self.favoritePrimes) = newValue }
    }
}
// CounterView управляет не только своим state, но и может открыть еще primeModal, поэтому создается новый enum и case называются как в AppAction, но только те которые нужны
public enum CounterViewAction: Equatable {
    case counter(CounterAction)
    case primeModal(PrimeModalAction)
    
//    var counter: CounterAction? {
//        get {
//            guard case let .counter(value) = self else { return nil }
//            return value
//        }
//        set {
//            guard case .counter = self, let newValue = newValue else { return }
//            self = .counter(newValue)
//        }
//    }
//
//    var primeModal: PrimeModalAction? {
//        get {
//            guard case let .primeModal(value) = self else { return nil }
//            return value
//        }
//        set {
//            guard case .primeModal = self, let newValue = newValue else { return }
//            self = .primeModal(newValue)
//        }
//    }
}

public struct CounterView: View {
    // @State is for local state, если мы уйдем с экрана и вернемся, то count сбросится на 0
//    @State var count: Int = 0
    //        self.$count // Binding of <Int>

    // чтобы сохранялось состояние надо использовать @ObjectBinding(deprecated, теперь @ObservedObject) нашего собственноого типа AppState, который конформит protocol BindableObject(deprecated)
    @ObservedObject var store: Store<CounterViewState, CounterViewAction>
//    @State var isPrimeModalShown: Bool = false
//    @State var alertNthPrime: PrimeAlert?
//    @State var isNthPrimeButtonDisabled = false
    
    public init(store: Store<CounterViewState, CounterViewAction>) {
        print("CounterView.init")
        self.store = store
    }
    
    public var body: some View {
        print("CounterView.body")
        return VStack {
            HStack {
                Button("-") { self.store.send(.counter(.decrTapped)) }
                Text("\(self.store.value.count)")
                Button("+") { self.store.send(.counter(.incrTapped)) }
            }
            Button("Is this prime?") { self.store.send(.counter(.isPrimeButtonTapped)) }
            Button("What is the \(ordinal(self.store.value.count)) prime?", action: self.nthPrimeButtonAction)
                .disabled(self.store.value.isNthPrimeButtonDisabled)
        }
        .font(.title)
        .navigationBarTitle("Counter demo")
        // will present modally when isPrimeModalShown is true and dismiss when is false
        // sheet is used instead of presentation now
//        .presentation(
//            self.isPrimeModalShown
//            ? Modal(
//                Text("I don't know if \(self.store.value.count) is prime")
//                onDismiss: { self.isPrimeModalShown = false }
//            )
//            : nil
//        )
        // так как храним уже не в @State, поэтому используем .constant
//        .sheet(isPresented: self.$isPrimeModalShown) {
        .sheet(
            isPresented: .constant(self.store.value.isPrimeModalShown),
            onDismiss: { self.store.send(.counter(.primeModalDismissed)) }
        ) {
            IsPrimeModalView(
                store: self.store
                    .view(
                        value: { ($0.count, $0.favoritePrimes) },
                        action: { .primeModal($0) }
                    )
            )
        }
        // будет показан когда alertNthPrime не nil (уже deprecated)
//        .alert(item: self.$alertNthPrime) { alert in
        .alert(
            // так как мы храним alertNthPrime в store как просто проперти, а нам надо передавать Binding, то нужно самим создать Binding здесь
//            item: Binding(get: { self.store.value.alertNthPrime }, set: { _ in })
            // но еще проще создать Binding (у которого нет setter'а) так:
            item: .constant(self.store.value.alertNthPrime)
        ) { alert in
            Alert(
                title: Text(alert.title),
                dismissButton: Alert.Button.default(Text("Ok")) {
                    self.store.send(.counter(.alertDismissButtonTapped))
                }
            )
        }
    }
    
    func nthPrimeButtonAction() {
//        self.isNthPrimeButtonDisabled = true
//        nthPrime(self.store.value.count) { prime in
//            if let prime = prime {
//                self.alertNthPrime = PrimeAlert(prime: prime)
//            }
//            self.isNthPrimeButtonDisabled = false
//        }
        self.store.send(.counter(.nthPrimeButtonTapped))
    }
}
