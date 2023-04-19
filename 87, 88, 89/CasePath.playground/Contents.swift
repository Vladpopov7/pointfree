import Foundation

struct User {
    var id: Int
    let isAdmin: Bool
    var location: Location
    var name: String
}
struct Location {
    var city: String
    var country: String
}

// Key path is a set of getter and setter functions
\User.id as WritableKeyPath<User, Int> // если бы id был let, то мы бы имели доступ только к KeyPah, а не к  WritableKeyPath
\User.isAdmin as KeyPath<User, Bool>
\User.name

var user = User(id: 42, isAdmin: true, location: Location(city: "Brooklyn", country: "USA"), name: "Blob")

user[keyPath: \.id] // 42

user[keyPath: \.id] = 57

user.id = 57
user.name = "Blob Jr."

class Label: NSObject {
  @objc dynamic var font = "Helvetica"
  @objc dynamic var fontSize = 12
  @objc dynamic var text = ""
}

class Model: NSObject {
  @objc dynamic var userName = ""
}

let model = Model()
let label = Label()

bind(model: model, \.userName, to: label, \.text)

//bind(model: model, get: { $0.userName }, to: label, get: { $0.text }, set: { $0.text = $1 })

label.text
model.userName = "blob"
label.text
model.userName = "XxFP_FANxX93"
label.text

import Combine

let subject = PassthroughSubject<String, Never>()
subject.assign(to: \.text, on: label)

subject.send("MaTh_FaN96")
label.text


typealias Reducer<Value, Action> = (inout Value, Action) -> Void

[1, 2, 3]
  .reduce(into: 0, { $0 += $1 })
[1, 2, 3]
  .reduce(into: 0, +=)


func pullback<GlobalValue, LocalValue, Action>(
  _ reducer: @escaping Reducer<LocalValue, Action>,
  value: WritableKeyPath<GlobalValue, LocalValue>
) -> Reducer<GlobalValue, Action> {

  return { globalValue, action in
//    var localValue = globalValue[keyPath: value]
//    reducer(&localValue, action)
//    globalValue[keyPath: value] = localValue
    reducer(&globalValue[keyPath: value], action)
  }
}

func pullback<GlobalValue, LocalValue, Action>(
  _ reducer: @escaping Reducer<LocalValue, Action>,
  getLocalValue: @escaping (GlobalValue) -> LocalValue,
  setLocalValue: @escaping (inout GlobalValue, LocalValue) -> Void
) -> Reducer<GlobalValue, Action> {

  return { globalValue, action in
    var localValue = getLocalValue(globalValue)
    reducer(&localValue, action)
    setLocalValue(&globalValue, localValue)
  }
}

let counterReducer: Reducer<Int, Void> = { count, _ in count += 1 }

pullback(counterReducer, value: \User.id)

[1, 2, 3]
  .map(String.init)

pullback(
  counterReducer,
  getLocalValue: { (user: User) in user.id },
  setLocalValue: { $0.id = $1 }
)


struct _WritableKeyPath<Root, Value> {
  let get: (Root) -> Value
  let set: (inout Root, Value) -> Void
}


// [user valueForKeyPath:@"location.city"]

struct CasePath<Root, Value> {
  let extract: (Root) -> Value?
  let embed: (Value) -> Root
}

extension Result {
  static var successCasePath: CasePath<Result, Success> {
    CasePath<Result, Success>(
      extract: { result -> Success? in
        if case let .success(value) = result {
          return value
        }
        return nil
    },
      embed: Result.success
    )
  }

  static var failureCasePath: CasePath<Result, Failure> {
    CasePath<Result, Failure>(
      extract: { result -> Failure? in
        if case let .failure(value) = result {
          return value
        }
        return nil
    },
      embed: Result.failure
    )
  }
}

Result<Int, Error>.successCasePath
Result<Int, Error>.failureCasePath

\User.location
\Location.city

// key path от User до city типа String (более короткая запись на след строке)
(\User.location).appending(path: \Location.city)
\User.location.city

extension CasePath/*<Root, Value>*/ {
    func appending<AppendedValue>(
        path: CasePath<Value, AppendedValue>
    ) -> CasePath<Root, AppendedValue> {
        CasePath<Root, AppendedValue>(
            extract: { root in
                self.extract(root).flatMap(path.extract)
            },
            embed: { appendedValue in
                self.embed(path.embed(appendedValue))
            })
    }
}

enum Authentication {
    case authenticated(AccessToken)
    case unauthenticated
}

struct AccessToken {
    var token: String
}

let authenticatedCasePath = CasePath<Authentication, AccessToken>(
    extract: {
        if case let .authenticated(accessToken) = $0 { return accessToken }
        return nil
    },
    embed: Authentication.authenticated
)

Result<Authentication, Error>.successCasePath
    .appending(path: authenticatedCasePath)
// реальный тип строк выше это
// CasePath‹Result<Authentication, Error>, AccessToken>

\User.location.city

precedencegroup Composition {
    associativity: right
}
infix operator ..: Composition

func .. <A, B, C> (
    lhs: CasePath<A, B>,
    rhs: CasePath<B, C>
) -> CasePath<A, C> {
    lhs.appending(path: rhs)
}

// к одному CasePath делаем appending другого
Result<Authentication, Error>.successCasePath .. authenticatedCasePath

// “identity” key path
\User.self
\Location.self
\String.self
\Int.self

extension CasePath where Root == Value {
    static var `self`: CasePath {
        return CasePath(
            extract: { .some($0) },
            embed: { $0 }
        )
    }
}

CasePath<Authentication, Authentication>.`self`

// уже можно просто использовать \. например для функции map, и этот prefix кастомный не нужен будет
prefix operator ^
prefix func ^ <Root, Value>(
    _ kp: KeyPath<Root, Value>
) -> (Root) -> Value {
    return { root in root[keyPath: kp] }
}

let users = [
    User(
        id: 1,
        isAdmin: true,
        location: Location(city: "Brooklyn", country: "USA"),
        name: "Blob"
    ),
    User(
        id: 2,
        isAdmin: false,
        location: Location(city: "Los Angeles", country: "USA"),
        name: "Blob Jr."
    ),
    User(
        id: 3,
        isAdmin: true,
        location: Location(city: "Copenhagen", country: "DK"),
        name: "Blob Sr."
    ),
]

// уже можно просто использовать \. например для функции map
//users.map(\.name)
users
    .map(^\.name)
users
    .map(^\.id)
users
    .filter(^\.isAdmin)

// сейчас это доступно:
users.map(\.name)
users.map(\.location.city)
users.filter(\.isAdmin)

prefix func ^ <Root, Value> (
    path: CasePath<Root, Value>
) -> (Root) -> Value? {
    return path.extract
}

// Authentication to Optional AccessToken
^authenticatedCasePath

let authentications: [Authentication] = [
    .authenticated(AccessToken(token: "deadbeef")),
    .unauthenticated,
    .authenticated(AccessToken(token: "cafed00d"))
]

authentications
    .compactMap(^authenticatedCasePath)

// код выше заменяет такую конструкцию
authentications
    .compactMap { (authentication) -> AccessToken? in
        if case let .authenticated(accessToken) = authentication {
            return accessToken
        }
        return nil
    }

// It turns out, for case paths in particular we can do something different. We can magically derive the extract function for a case path from just the embed function that comes from the case of an enum. We say this is “magical” because it uses Swift’s runtime reflection capabilities.
// reflection allows you to inspect the internal structure of values and objects at runtime. For example, you can use reflection to get a list of all of the string names of stored properties that a struct has.

func allProperties(_ value: Any) -> [String] {
    let mirror = Mirror(reflecting: value)
    return mirror.children.compactMap { child in child.label }
}

// все проперти структуры User
allProperties(user)

let auth = Authentication.authenticated(AccessToken(token: "deadbeef"))

let mirror = Mirror(reflecting: auth)
// dump - Dumps the given object’s contents using its mirror to standard output. (пишет в консоль)
dump(mirror.children.first!)

mirror.children.first!.value as? AccessToken

func extractHelp<Root, Value>(
    case: (Value) -> Root,
    from root: Root
) -> Value? {
    let mirror = Mirror(reflecting: root)
    guard let child = mirror.children.first else { return nil }
    guard let value = child.value as? Value else { return nil }
    
    let newRoot = `case`(value)
    let newMirror = Mirror(reflecting: newRoot)
    guard let newChild = newMirror.children.first else { return nil }
    guard newChild.label == child.label else { return nil }
    
    return value
}

extractHelp(case: Authentication.authenticated, from: auth)
extractHelp(case: Authentication.authenticated, from: .unauthenticated)

extractHelp(case: Result<Int, Error>.success, from: .success(42))

struct MyError: Error {}

extractHelp(case: Result<Int, Error>.failure, from: .failure(MyError()))

enum Example {
    case foo(Int)
    case bar(Int)
}

Example.foo
Example.bar

extractHelp(case: Example.foo, from: .foo(2))
// возвращает nil, так как case указали bar а from .foo
extractHelp(case: Example.bar, from: .foo(2))

mirror.children.first!.label

extension CasePath {
    init(_ embed: @escaping (Value) -> Root) {
        self.embed = embed
        self.extract = { root in extractHelp(case: embed, from: root) }
    }
}

// case path from Example to foo Int
CasePath(Example.foo)
CasePath(Example.bar)
CasePath(Result<Int, MyError>.success)

enum ExampleWithArgumentLabels {
    case foo(value: Int)
}

extractHelp(case: ExampleWithArgumentLabels.foo, from: .foo(value: 42))

//extractHelp(case: Authentication.unauthenticated, from: .unauthenticated)

let locationCountryCasePath = CasePath<Location, String>(
    { country in Location(city: "Brooklyn", country: country) }
)
// we don't get the country, we get the city
// This is of course silly because Location is a struct, and so it’s more appropriate to use key paths to focus on its parts rather than case paths. But still, nothing is preventing us from writing this strange code. And if we do that, the case path will not do what we expect:
locationCountryCasePath.extract(user.location)

CasePath(Result<Int, Error>.success)
CasePath(Result<String, Error>.success)
CasePath(Result<String, Error>.failure)
CasePath(Result<String, NSError>.failure)

CasePath(Optional<Int>.some)
CasePath(Optional<String>.some)
CasePath(Optional<[Int]>.some)

CasePath(DispatchTimeInterval.seconds)
CasePath(DispatchTimeInterval.milliseconds)
CasePath(DispatchTimeInterval.microseconds)
CasePath(DispatchTimeInterval.nanoseconds)

CasePath(Subscribers.Completion<Error>.failure)

prefix operator /

prefix func / <Root, Value> (
  case: @escaping (Value) -> Root
) -> CasePath<Root, Value> {
  CasePath(`case`)
}

\User.id
/DispatchTimeInterval.seconds

CasePath(DispatchTimeInterval.seconds)

/Result<DispatchTimeInterval, Error>.success .. /DispatchTimeInterval.seconds

enum LoadState<A> {
    case loading
    case offline
    case loaded(Result<A, Error>)
}

/LoadState<Int>.loaded .. /Result.success

let states1: [LoadState<Int>] = [
    .loaded(.success(2)),
    .loaded(.failure(NSError(domain: "", code: 1, userInfo: [:]))),
    .loaded(.success(3)),
    .loading,
    .loaded(.success(4)),
    .offline,
]

// [2, 3, 4]
states1
    .compactMap(^(/LoadState.loaded .. /Result.success))

let states2: [LoadState<Authentication>] = [
    .loading,
    .loaded(.success(.authenticated(AccessToken(token: "deadbeef")))),
    .loaded(.failure(NSError(domain: "", code: 1, userInfo: [:]))),
    .loaded(.success(.authenticated(AccessToken(token: "cafed00d")))),
    .loaded(.success(.unauthenticated)),
    .offline,
]

/LoadState.loaded .. /Result.success .. /Authentication.authenticated
/LoadState.loaded .. /Result.success .. /Authentication.authenticated

// [{token "deadbeef"}, {token "cafed00d"}]
states2
    .compactMap(^(/LoadState.loaded .. /Result.success .. /Authentication.authenticated))

// то же самое, но длиннее
states2
    .compactMap { state -> AccessToken? in
        if case let .loaded(.success(.authenticated(accessToken))) = state { return accessToken }
        return nil
    }
