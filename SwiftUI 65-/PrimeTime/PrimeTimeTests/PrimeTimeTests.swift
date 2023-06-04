import XCTest
@testable import PrimeTime
import ComposableArchitecture
@testable import Counter
@testable import FavoritePrimes
import PrimeAlert
@testable import PrimeModal
import ComposableArchitectureTestSupport

class PrimeTimeTests: XCTestCase {
    func testIntegration() {
        var fileClient = FileClient.mock
        fileClient.load = { _ in Effect<Data?>.sync {
            try! JSONEncoder().encode ([2, 31, 7])
        } }
        
        assert(
            initialValue: AppState(count: 4),
            reducer: appReducer,
            environment: (
                fileClient: fileClient,
                nthPrime: { _ in .sync { 17 } },
                offlineNthPrime: { _ in .sync { 17 } }
            ),
            steps:
            Step(.send, .counterView(.counter(.requestNthPrime))) {
                $0.isNthPrimeRequestInFlight = true
            },
            Step(.receive, .counterView(.counter(.nthPrimeResponse(n: 4, prime: 17)))) {
                $0.isNthPrimeRequestInFlight = false
                $0.alertNthPrime = PrimeAlert(n: 4, prime: 17)
            },
            // step doesn't expect state to change, that's why it doesn't have a closure
            Step(.send, .favoritePrimes(.loadButtonTapped)),
            Step(.receive, .favoritePrimes(.loadedFavoritePrimes([2, 31, 7]))) {
                $0.favoritePrimes = [2, 31, 7]
            }
        )
    }
}
