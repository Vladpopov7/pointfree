//
//  FileClient.swift
//  FavoritePrimes
//
//  Created by Vladislav Popov on 04/06/2023.
//

import ComposableArchitecture
import Foundation

public struct FileClient {
    var load: (String) -> Effect<Data?>
    var save: (String, Data) -> Effect<Never>
}

extension FileClient {
    public static let live = FileClient(
        load: { fileName -> Effect<Data?> in
            .sync {
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let documentUrl = URL(fileURLWithPath: documentsPath)
                let favoritePrimesUrl = documentUrl.appendingPathComponent(fileName)
                return try? Data(contentsOf: favoritePrimesUrl)
            }
        },
        save: { fileName, data in
            return .fireAndForget {
                // the reducer itself doesn't produce a side effect since we're saving to disk inside the return function of the Effect
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let documentUrl = URL(fileURLWithPath: documentsPath)
                let favoritePrimesUrl = documentUrl.appendingPathComponent(fileName)
                try! data.write(to: favoritePrimesUrl)
            }
        }
    )
}

#if DEBUG
extension FileClient {
    static let mock = FileClient(
        load: { _ in Effect<Data?>.sync {
            try! JSONEncoder().encode ([2, 31])
        } },
        save: { _, _ in .fireAndForget {} }
    )
}
#endif
