import SwiftUI
import Combine

// BindableObject is deprecated
//class AppState: BindableObject {
//    var count = 0 {
//        didSet {
//            // так мы уведомим всех подписчиков, кто использует AppState
//            self.didChange.send()
//        }
//    }
//
//    var didChange = PassthroughSubject<Void, Never>
//}

// ObservableObject - This protocol utilizes an objectWillChange property of ObservableObjectPublisher, which is pinged before (not after) any mutations are made to your model
// let objectDidChange = ObservableObjectPublisher()
// This boilerplate is also not necessary, as the ObservableObject protocol will synthesize a default publisher for you automatically.
struct AppState {
//    With Xcode 11 beta 5 and later, willSet should be used instead of didSet:
//    var count = 0 {
//      willSet {
//        self.objectWillChange.send()
//      }
//    }
//    Or you can remove this boilerplate entirely by using a @Published property wrapper:
    var count = 0
    
//    var favoritePrimes: [Int] = [] {
//        // notify anyone who use this AppState, that the state will be changed
//        willSet { self.objectWillChange.send() }
//    }
    // можно не использовать willSet а просто сделать @Published проперти и оно само уведомит всех кто использует AppState
    var favoritePrimes: [Int] = []
    var loggedInUser: User?
    var activityFeed: [Activity] = []
    
    struct Activity {
        let timestamp: Date
        let type: ActivityType
        
        enum ActivityType {
            case addedFavoritePrime(Int)
            case removedFavoritePrime(Int)
        }
    }
    
    struct User {
        let id: Int
        let name: String
        let bio: String
    }
}

enum CounterAction {
    case decrTapped
    case incrTapped
}
enum PrimeModalAction {
    case saveFavoritePrimeTapped
    case removeFavoritePrimeTapped
}
enum FavoritePrimesAction {
    case deleteFavoritePrimes(IndexSet)
}
// this action nests other actions for different screens
enum AppAction {
    case counter(CounterAction)
    case primeModal(PrimeModalAction)
    case favoritePrimes(FavoritePrimesAction)
    
    // это как keyPath, только для Actions (так как это enum)
    var counter: CounterAction? {
        get {
            guard case let .counter(value) = self else { return nil }
            return value
        }
        set {
            guard case .counter = self, let newValue = newValue else { return }
            self = .counter(newValue)
        }
    }
    
    var primeModal: PrimeModalAction? {
        get {
            guard case let .primeModal(value) = self else { return nil }
            return value
        }
        set {
            guard case .primeModal = self, let newValue = newValue else { return }
            self = .primeModal(newValue)
        }
    }
    
    var favoritePrimes: FavoritePrimesAction? {
        get {
            guard case let .favoritePrimes(value) = self else { return nil }
            return value
        }
        set {
            guard case .favoritePrimes = self, let newValue = newValue else { return }
            self = .favoritePrimes(newValue)
        }
    }
}

//let someAction = AppAction.counter(.incrTapped)
//someAction.counter
//someAction.favoritePrimes
//
//// key path from AppAction to CounterAction
//\AppAction.counter

func counterReducer(state: inout Int, action: CounterAction) {
    switch action {
    case .decrTapped:
        state -= 1
        
    case .incrTapped:
        state += 1
    }
}

func primeModalReducer(state: inout AppState, action: PrimeModalAction) {
    switch action {
    case .saveFavoritePrimeTapped:
        state.favoritePrimes.append(state.count)
        
    case .removeFavoritePrimeTapped:
        state.favoritePrimes.removeAll(where: { $0 == state.count })
    }
}

//struct FavoritePrimesState {
//    var favoritePrimes: [Int]
//    var activityFeed: [AppState.Activity]
//}

func favoritePrimesReducer(state: inout [Int], action: FavoritePrimesAction) {
    switch action {
    case let .deleteFavoritePrimes(indexSet):
        for index in indexSet {
            state.remove(at: index)
        }
    }
}

func combine<Value, Action>(
    _ reducers: (inout Value, Action) -> Void...
) -> (inout Value, Action) -> Void {
    return { value, action in
        for reducer in reducers {
            reducer(&value, action)
        }
    }
}

final class Store<Value, Action>: ObservableObject {
    let reducer: (inout Value, Action) -> Void
    // private(set) чтобы нельзя было менять это значение кроме как через метод  send(_ action: Action)
    @Published private(set) var value: Value
    
    init(initialValue: Value, reducer: @escaping (inout Value, Action) -> Void) {
        self.reducer = reducer
        self.value = initialValue
    }
    
    func send(_ action: Action) {
        self.reducer(&self.value, action)
    }
}

func pullback<LocalValue, GlobalValue, LocalAction, GlobalAction>(
    _ reducer: @escaping (inout LocalValue, LocalAction) -> Void,
    value: WritableKeyPath<GlobalValue, LocalValue>,
    action: WritableKeyPath<GlobalAction, LocalAction?>
) -> (inout GlobalValue, GlobalAction) -> Void {
    return { globalValue, globalAction in
        guard let localAction = globalAction[keyPath: action] else { return }
        reducer(&globalValue[keyPath: value], localAction)
    }
}

//extension AppState {
//    var favoritePrimesState: FavoritePrimesState {
//        get {
//            FavoritePrimesState(
//                favoritePrimes: self.favoritePrimes,
//                activityFeed: self.activityFeed
//            )
//        }
//        set {
//            self.favoritePrimes = newValue.favoritePrimes
//            self.activityFeed = newValue.activityFeed
//        }
//    }
//}

struct _KeyPath<Root, Value> {
    let get: (Root) -> Value
    let set: (inout Root, Value) -> Void
}

AppAction.counter(CounterAction.incrTapped)

let action = AppAction.favoritePrimes(FavoritePrimesAction.deleteFavoritePrimes([1]))
let favoritePrimes: FavoritePrimesAction?
switch action {
case let .favoritePrimes(action):
    favoritePrimes = action
default:
    favoritePrimes = nil
}

struct EnumKeyPath<Root, Value> {
    let embed: (Value) -> Root
    let extract: (Root) -> Value?
}
// \AppAction.counter // EnumKeyPath<AppAction, CounterAppAction>

// higher order function
func activityFeed(
    _ reducer: @escaping (inout AppState, AppAction) -> Void
) -> (inout AppState, AppAction) -> Void {
    
    return { state, action in
        switch action {
        case .counter:
            break
        case .primeModal(.removeFavoritePrimeTapped):
            state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))
        case .primeModal(.saveFavoritePrimeTapped):
            state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))
        case let  .favoritePrimes(.deleteFavoritePrimes(indexSet)):
            for index in indexSet {
                state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.favoritePrimes[index])))
            }
        }

        reducer(&state, action)
    }
}

let _appReducer: (inout AppState, AppAction) -> Void = combine(
    // counterReducer передаем как функцию которая будет работать с локальным типом данных Int, сначала получив Int через переданную фнкцию get, и затем записав измененное значение в global state через set функцию
//    pullback(counterReducer, get: { $0.count }, set: { $0.count = $1 }),
    // использование keyPath вместо get и set
    pullback(counterReducer, value: \.count, action: \.counter),
    pullback(primeModalReducer, value: \.self, action: \.primeModal),
    pullback(favoritePrimesReducer, value: \.favoritePrimes, action: \.favoritePrimes)
)
// \.self represents the key path from AppState to AppState where the getter just returns self and the setter just replaces itself with the new value coming in. This pullback has not changed the app reducer at all, the _appReducer and the appReducer behave exactly the same.
let appReducer = pullback(_appReducer, value: \.self, action: \.self)

var state = AppState()

func logging<Value, Action>(
    _ reducer: @escaping (inout Value, Action) -> Void
) -> (inout Value, Action) -> Void {
    return { value, action in
        reducer(&value, action)
        print("Action: \(action)")
        print("Value:")
        dump(value)
        print("---")
    }
}

struct PrimeAlert: Identifiable {
    let prime: Int
    
    var id: Int { self.prime }
}

struct CounterView: View {
    // @State is for local state, если мы уйдем с экрана и вернемся, то count сбросится на 0
//    @State var count: Int = 0
    //        self.$count // Binding of <Int>

    // чтобы сохранялось состояние надо использовать @ObjectBinding(deprecated, теперь @ObservedObject) нашего собственноого типа AppState, который конформит protocol BindableObject(deprecated)
    @ObservedObject var store: Store<AppState, AppAction>
    @State var isPrimeModalShown: Bool = false
    @State var alertNthPrime: PrimeAlert?
    @State var isNthPrimeButtonDisabled = false
    
    var body: some View {
        VStack {
            HStack {
                Button("-") { self.store.send(.counter(.decrTapped)) }
                Text("\(self.store.value.count)")
                Button("+") { self.store.send(.counter(.incrTapped)) }
            }
            Button("Is this prime?") { self.isPrimeModalShown = true }
            Button("What is the \(ordinal(self.store.value.count)) prime?", action: self.nthPrimeButtonAction)
            .disabled(self.isNthPrimeButtonDisabled)
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
        .sheet(isPresented: self.$isPrimeModalShown) {
            IsPrimeModalView(store: self.store)
        }
        // будет показан когда alertNthPrime не nil (уже deprecated)
        .alert(item: self.$alertNthPrime) { alert in
            Alert(
                title: Text("The \(ordinal(self.store.value.count)) prime is \(alert.prime)"),
                dismissButton: Alert.Button.default(Text("Ok"))
            )
        }
    }
    
    func nthPrimeButtonAction() {
        self.isNthPrimeButtonDisabled = true
        nthPrime(self.store.value.count) { prime in
            if let prime = prime {
                self.alertNthPrime = PrimeAlert(prime: prime)
            }
            self.isNthPrimeButtonDisabled = false
        }
    }
}

struct IsPrimeModalView: View {
    @ObservedObject var store: Store<AppState, AppAction>
    
    var body: some View {
        VStack {
            if isPrime(self.store.value.count) {
                Text("\(self.store.value.count) is prime 🎉")
                if self.store.value.favoritePrimes.contains(self.store.value.count) {
                    Button("Remove from favorite primes") {
                        store.send(.primeModal(.removeFavoritePrimeTapped))
                    }
                } else {
                    Button("Save to favorite primes") {
                        store.send(.primeModal(.saveFavoritePrimeTapped))
                    }
                }
            } else {
                Text("\(self.store.value.count) is not prime :(")
            }
        }
    }
}

struct FavoritePrimesView: View {
    @ObservedObject var store: Store<AppState, AppAction>

    var body: some View {
        List {
            ForEach(self.store.value.favoritePrimes, id: \.self) { prime in
                Text("\(prime)")
            }
            .onDelete { indexSet in
                self.store.send(.favoritePrimes(.deleteFavoritePrimes(indexSet)))
            }
        }
        .navigationBarTitle(Text("Favorite Primes"))
    }
}

struct ContentView: View {
    @ObservedObject var store: Store<AppState, AppAction>
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink(
                    "Counter demo",
                    destination: CounterView(store: self.store)
                )
                NavigationLink(
                    "Favorite primes",
                    destination: FavoritePrimesView(store: self.store)
                )
            }
        }
        .navigationBarTitle("State management")
        // fix, to display UIHostingController
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// import Overture

import PlaygroundSupport

PlaygroundPage.current.liveView = UIHostingController(
    rootView: ContentView(
        store: Store(
            initialValue: AppState(),
            // добавили функционал отслеживания activityFeed, вместо того чтобы просто передать appReducer, и так же logging. Но так как при дальнейшем добавлении других функций цепочка может стать слишком длинной, поэтому используаем функции with и compose из их библиотеки и в дальнейшем просто сможем добавлять функции как параметры в compose функцию по порядку (aspect oriented programming)
//            reducer: logging(activityFeed(appReducer))
            reducer: with(
                appReducer,
                compose(
                    logging,
                    activityFeed
                )
            )
        )
    )
)
