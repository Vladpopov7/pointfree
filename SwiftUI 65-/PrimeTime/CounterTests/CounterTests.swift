import XCTest
@testable import Counter
import SnapshotTesting
import ComposableArchitecture
import ComposableArchitectureTestSupport
import SwiftUI


extension Snapshotting where Value: UIViewController, Format == UIImage {
  static var windowedImage: Snapshotting {
    return Snapshotting<UIImage, UIImage>.image.asyncPullback { vc in
      Async<UIImage> { callback in
        UIView.setAnimationsEnabled(false)
        let window = UIApplication.shared.windows.first!
        window.rootViewController = vc
        DispatchQueue.main.async {
          let image = UIGraphicsImageRenderer(bounds: window.bounds).image { ctx in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
          }
          callback(image)
          UIView.setAnimationsEnabled(true)
        }
      }
    }
  }
}

class CounterTests: XCTestCase {
//    override class func setUp() {
//        super.setUp()
//        // it completely mocks out the environment for all of our tests in this file
//        Current = .mock
//    }
    
//    func testSnapshots() {
//        let store = Store(initialValue: CounterViewState(), reducer: counterViewReducer, environment: { _ in .sync { 17 } })
//        let view = CounterView(store: store)
//
//        let vc = UIHostingController(rootView: view)
//        vc.view.frame = UIScreen.main.bounds
//
//        // при первом запуске зафейлится, нужно будет взять строку начинающуюся на open... из выскочившей ошибки и вставить в terminal
//        // record включает режим записи, по строке из ошибки можно получить доступ к сгенерированному image
////        isRecording=true
//        assertSnapshot(matching: vc, as: .windowedImage)
//
//        store.send(.counter(.incrTapped))
//        assertSnapshot(matching: vc, as: .windowedImage)
//
//        store.send(.counter(.incrTapped))
//        assertSnapshot(matching: vc, as: .windowedImage)
//
//        store.send(.counter(.nthPrimeButtonTapped))
//        assertSnapshot(matching: vc, as: .windowedImage)
//
//        var expectation = self.expectation(description: "wait")
//        DispatchQueue.main.asyncAfter (deadline: .now() + 0.5) {
//            expectation.fulfill()
//        }
//        self.wait(for: [expectation], timeout: 0.5)
//        assertSnapshot(matching: vc, as: .windowedImage)
//
//        store.send(.counter(.alertDismissButtonTapped))
//        expectation = self.expectation(description: "wait")
//        DispatchQueue.main.asyncAfter (deadline: .now() + 0.5) {
//            expectation.fulfill()
//        }
//        self.wait(for: [expectation], timeout: 0.5)
//        assertSnapshot(matching: vc, as: .windowedImage)
//
//        store.send(.counter(.isPrimeButtonTapped))
//        assertSnapshot(matching: vc, as: .windowedImage)
//
//        store.send(.primeModal(.saveFavoritePrimeTapped))
//        assertSnapshot(matching: vc, as: .windowedImage)
//
//        store.send(.counter(.primeModalDismissed))
//        assertSnapshot(matching: vc, as: .windowedImage)
//    }
    
    func testIncrDecrButtonTapped() {
        assert(
            initialValue: CounterViewState(count: 2),
            reducer: counterViewReducer,
            environment: { _ in .sync { 17 }},
            steps:
                // мы ожидаем что count увеличится при incrTapped и уменьшится при decrTapped
            Step(.send, .counter(.incrTapped)) { $0.count = 3 },
            Step(.send, .counter(.incrTapped)) { $0.count = 4 },
            Step(.send, .counter(.decrTapped)) { $0.count = 3 }
        )
        
        // замена кода более коротко (выше)
//        var state = CounterViewState(count: 2)
//        var expected = state
//        let effects = counterViewReducer(&state, .counter(.incrTapped))
//
//        expected.count = 3
//        XCTAssertEqual(state, expected)
//        XCTAssertTrue(effects.isEmpty)
    }
    
    func testNthPrimeButtonHappyFlow() {
//        Current.nthPrime =
        
        assert(
            initialValue: CounterViewState(
                alertNthPrime: nil,
                count: 7,
                isNthPrimeButtonDisabled: false
            ),
            reducer: counterViewReducer,
            environment: { _ in .sync { 17 } },
            steps:
                Step(.send, .counter(.nthPrimeButtonTapped)) {
                    $0.isNthPrimeButtonDisabled = true
                },
            Step(.receive, .counter(.nthPrimeResponse(n: 7, prime: 17))) {
                $0.alertNthPrime = PrimeAlert(n: $0.count, prime: 17)
                $0.isNthPrimeButtonDisabled = false
            },
            Step(.send, .counter(.alertDismissButtonTapped)) {
                $0.alertNthPrime = nil
            }
        )
        // код выше - это краткая запись закомментированного кода
//        var state = CounterViewState (
//            alertNthPrime: nil,
//            isNthPrimeButtonDisabled: false
//        )
//        var expected = state
//
//        var effects = counterViewReducer(&state, .counter(.nthPrimeButtonTapped))
//        expected.isNthPrimeButtonDisabled = true
//        XCTAssertEqual(state, expected)
//        XCTAssertEqual(effects.count, 1)
//
//        var nextAction: CounterViewAction!
//        let receivedCompletion = self.expectation(description: "receivedCompletion")
//        let cancellable = effects[0].sink(
//            receiveCompletion: { _ in
//                receivedCompletion.fulfill()
//            },
//            receiveValue: { action in
//                XCTAssertEqual(action, .counter(.nthPrimeResponse(17)))
//                nextAction = action
//            }
//        )
//        // timeout 0 не достаточно, потому что в .nthPrimeButtonTapped мы делаем .receive(on: DispatchQueue.main)
//        self.wait(for: [receivedCompletion], timeout: 0.01)
//
//        effects = counterViewReducer(&state, nextAction)
//        expected.alertNthPrime = PrimeAlert(prime: 17)
//        expected.isNthPrimeButtonDisabled = false
//        XCTAssertEqual(state, expected)
//        XCTAssertTrue(effects.isEmpty)
//
//        effects = counterViewReducer(&state, .counter(.alertDismissButtonTapped))
//
//        expected.alertNthPrime = nil
//        XCTAssertEqual(state, expected)
//        XCTAssertTrue(effects.isEmpty)
    }
    
    func testNthPrimeButtonUnhappyFlow() {
//        Current.nthPrime =
        
        assert(
            initialValue: CounterViewState(
                alertNthPrime: nil,
                count: 7,
                isNthPrimeButtonDisabled: false
            ),
            reducer: counterViewReducer,
            environment: { _ in .sync { nil } },
            steps:
                Step(.send, .counter(.nthPrimeButtonTapped)) {
                    $0.isNthPrimeButtonDisabled = true
                },
            Step(.receive, .counter(.nthPrimeResponse(n: 7, prime: nil))) {
                $0.isNthPrimeButtonDisabled = false
            }
        )
    }

    func testPrimeModal() {
//        Current = .mock
        
        assert(
            initialValue: CounterViewState(
                count: 2,
                favoritePrimes: [3, 5]
            ),
            reducer: counterViewReducer,
            environment: { _ in .sync { 17 } },
            steps:
                Step(.send, .primeModal(.saveFavoritePrimeTapped)) {
                    $0.favoritePrimes = [3, 5, 2]
                },
            Step(.send, .primeModal(.removeFavoritePrimeTapped)) {
                $0.favoritePrimes = [3, 5]
            }
        )
    }
}
