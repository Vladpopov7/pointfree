//
//  PrimeTimeApp.swift
//  PrimeTime
//
//  Created by Vladislav Popov on 27/02/2023.
//

import ComposableArchitecture
import SwiftUI

@main
struct PrimeTimeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
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
                    )
                )
            )
        }
    }
}
