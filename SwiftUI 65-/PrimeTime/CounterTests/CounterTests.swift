import XCTest
@testable import Counter
import Combine

class CounterTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        Current = .mock
    }
    
    func testIncrDecrButtonTapped() {
        assert(
            initialValue: CounterViewState(count: 2),
            reducer: counterViewReducer,
            steps:
                // мы ожидаем что count увеличится при incrTapped и уменьшится при decrTapped
            Step(.send, .counter(.incrTapped)) { $0.count = 3 },
            Step(.send, .counter(.incrTapped)) { $0.count = 4 },
            Step(.send, .counter(.decrTapped)) { $0.count = 3 }
        )
        
        // замена кода выше более коротко
//        var state = CounterViewState(count: 2)
//        var expected = state
//        let effects = counterViewReducer(&state, .counter(.incrTapped))
//
//        expected.count = 3
//        XCTAssertEqual(state, expected)
//        XCTAssertTrue(effects.isEmpty)
    }
    
    func testNthPrimeButtonHappyFlow() {
        Current.nthPrime = { _ in .sync { 17 } }
        
        assert(
            initialValue: CounterViewState (
                alertNthPrime: nil,
                isNthPrimeButtonDisabled: false
            ),
            reducer: counterViewReducer,
            steps:
                Step(.send, .counter(.nthPrimeButtonTapped)) {
                    $0.isNthPrimeButtonDisabled = true
                },
            Step(.receive, .counter(.nthPrimeResponse(17))) {
                $0.alertNthPrime = PrimeAlert(prime: 17)
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
        Current.nthPrime = { _ in .sync { nil } }
        
        assert(
            initialValue: CounterViewState (
                alertNthPrime: nil,
                count: 2,
                favoritePrimes: [3, 5],
                isNthPrimeButtonDisabled: false
            ),
            reducer: counterViewReducer,
            steps:
                Step(.send, .counter(.nthPrimeButtonTapped)) {
                    $0.isNthPrimeButtonDisabled = true
                },
            Step(.receive, .counter(.nthPrimeResponse(nil))) {
                $0.isNthPrimeButtonDisabled = false
            }
        )
    }

    func testPrimeModal() {
        assert(
            initialValue: CounterViewState(
                count: 2,
                favoritePrimes: [3, 5]
            ),
            reducer: counterViewReducer,
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
