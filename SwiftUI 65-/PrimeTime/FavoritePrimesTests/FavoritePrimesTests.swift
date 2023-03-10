import XCTest
@testable import FavoritePrimes

final class FavoritePrimesTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        Current = .mock
    }
    
    func testDeleteFavoritePrimes() {
        var state = [2, 3, 5, 7]
        let effects = favoritePrimesReducer(state: &state, action: .deleteFavoritePrimes([2]))
        
        XCTAssertEqual (state, [2, 3, 7])
        XCTAssert(effects.isEmpty)
    }
    
    func testSaveButtonTapped() {
        var didSave = false
        Current.fileClient.save = { _, _ in
                .fireAndForget {
                    didSave = true
                }
        }
        
        var state = [2, 3, 5, 7]
        let effects = favoritePrimesReducer(state: &state, action: .saveButtonTapped)
        
        XCTAssertEqual (state, [2, 3, 5, 7])
        XCTAssertEqual(effects.count, 1)
        
        // test that the effect that was returned to us by a reducer is calling the correct effect in the environment
        effects[0].sink { _ in
            // we know that this effect should never be producing anything
            XCTFail()
        }
        XCTAssert(didSave)
    }
    
    func testLoadFavoritePrimesFlow() {
        Current.fileClient.load = { _ in
                .sync {
                    try! JSONEncoder().encode([2, 31])
                }
        }
        var state = [2, 3, 5, 7]
        var effects = favoritePrimesReducer(state: &state, action: .loadButtonTapped)
        
        XCTAssertEqual (state, [2, 3, 5, 7])
        XCTAssertEqual(effects.count, 1)
        
        var nextAction: FavoritePrimesAction!
        let receivedCompletion = self.expectation(description: "receivedCompletion")
        effects[0].sink(
            receiveCompletion: { _ in
                receivedCompletion.fulfill()
            },
            receiveValue: { action in
                XCTAssertEqual(action, .loadedFavoritePrimes([2, 31]))
                nextAction = action
            })
        // timeout is 0 because we are expecting receivedCompletion synchronously
        self.wait(for: [receivedCompletion], timeout: 0)
        
        effects = favoritePrimesReducer(state: &state, action: nextAction)
        
        XCTAssertEqual (state, [2, 31])
        XCTAssert(effects .isEmpty)
    }
}
