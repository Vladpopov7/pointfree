import UIKit
@testable import Counter

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // мы в UI тесте задаем 1 для этого ключа, и попадаем в этот if при UI тестах
        if ProcessInfo.processInfo.environment["UI_TESTS"] == "1" {
            // чтобы ускорить UI тесты
            UIView.setAnimationsEnabled(false)
//            Counter.Current.nthPrime = { _ in .sync { 3 } }
        }
        
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
