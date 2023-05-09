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
            initialValue: AppState(),
            // добавили функционал отслеживания activityFeed, вместо того чтобы просто передать appReducer, и так же logging. Но так как при дальнейшем добавлении других функций цепочка может стать слишком длинной, поэтому используаем функции with и compose из их библиотеки и в дальнейшем просто сможем добавлять функции как параметры в compose функцию по порядку (aspect oriented programming)
//            reducer: logging(activityFeed(appReducer))
            reducer: with(
              appReducer,
              compose(
                logging,
                activityFeed
              )
            ),
            environment: AppEnvironment(
                fileClient: .live,
                nthPrime: Counter.nthPrime
//                counter: .live,
//                favoritePrimes: .live
            )
          )
        )
      )
      self.window = window
      window.makeKeyAndVisible()
    }
  }
}
