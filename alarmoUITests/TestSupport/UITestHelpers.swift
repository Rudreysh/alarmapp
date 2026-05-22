import XCTest

enum UITestHelpers {
    static func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }
}
