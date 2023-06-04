import ComposableArchitecture
import Counter
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(
                rootView: ContentView(
                    store: Store(
                        // if you add a large count value, then offline calculation will be slow and the main queue will be loaded
                        //            initialValue: AppState(count: 40_000),
                        initialValue: AppState(),
                        // we've added activityFeed tracking functionality instead of just passing in an appReducer, and also logging. We use the with and compose functions from the library and in the future we can simply add functions as parameters to the compose function in order (aspect oriented programming)
                        reducer: appReducer
                            .activityFeed(),
                        // we can put logging here for the whole app level, or in some module (in the Counter module for example)
//                            .logging(),
                        environment: AppEnvironment(
                            fileClient: .live,
                            nthPrime: Counter.nthPrime,
                            offlineNthPrime: Counter.offlineNthPrime
                        )
                    )
                )
            )
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}
