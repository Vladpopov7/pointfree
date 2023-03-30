import XCTest
@testable import Counter

final class PrimeTimeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        Current = .mock
    }
    
    func testExample() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS"] = "1"
        app.launchEnvironment["UNHAPPY_PATHS"] = "1"
        app.launch()
        
        app.tables/*@START_MENU_TOKEN@*/.buttons["Counter demo"]/*[[".cells.buttons[\"Counter demo\"]",".buttons[\"Counter demo\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        let button = app.buttons["+"]
        button.tap()
        XCTAssert(app.staticTexts["1"].exists)
        button.tap()
        XCTAssert(app.staticTexts["2"].exists)
        app.buttons["What is the 2nd prime?"].tap()
        let alert = app.alerts["The 2nd prime is 3"]
        XCTAssert(alert.waitForExistence(timeout: 5))
        // тут фейлилось потому что для показа alert нужно время, поэтому создали let alert и wait for 5 seconds
        alert.scrollViews.otherElements.buttons["Ok"].tap()
        app.buttons["Is this prime?"].tap()
        app.buttons["Save to favorite primes"].tap()
        app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element(boundBy: 0).swipeDown()
                        
    }
}
