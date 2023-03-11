import Foundation

private let wolframAlphaApiKey = "6H69Q3-828TKQJ4EP"

struct WolframAlphaResult: Decodable {
    let queryresult: QueryResult
    
    struct QueryResult: Decodable {
        let pods: [Pod]
        
        struct Pod: Decodable {
            let primary: Bool?
            let subpods: [SubPod]
            
            struct SubPod: Decodable {
                let plaintext: String
            }
        }
    }
}

// сделали возврат Effect вместо параметра callback, и внутрь Effect передаем callback
func nthPrime(_ n: Int) -> Effect<Int?> {
//, callback: @escaping (Int?) -> Void) -> Void {
    return wolframAlpha(query: "prime \(n)").map { result in
        result
            .flatMap {
                $0.queryresult
                    .pods
                    .first(where: { $0.primary == .some(true) })?
                    .subpods
                    .first?
                    .plaintext
            }
            .flatMap(Int.init)
    }
    .eraseToEffect()
}

import ComposableArchitecture

// сделали возврат Effect вместо параметра callback, и внутрь Effect передаем callback
func wolframAlpha(query: String) -> Effect<WolframAlphaResult?> {
    //, callback: @escaping (WolframAlphaResult?) -> Void) -> Void {
    var components = URLComponents(string: "https://api.wolframalpha.com/v2/query")!
    components.queryItems = [
        URLQueryItem(name: "input", value: query),
        URLQueryItem(name: "format", value: "plaintext"),
        URLQueryItem(name: "output", value: "JSON"),
        URLQueryItem(name: "appid", value: wolframAlphaApiKey),
    ]
    
    return URLSession.shared
      .dataTaskPublisher(for: components.url(relativeTo: nil)!)
      .map { data, _ in data }
      .decode(type: WolframAlphaResult?.self, decoder: JSONDecoder())
      .replaceError(with: nil)
      .eraseToEffect()
    
//    return dataTask(with: components.url(relativeTo: nil)!)
//        .decode (as: WolframAlphaResult.self)
}

//return [Effect { callback in
//    nthPrime(count) { prime in
//        DispatchQueue.main.async {
//            callback(.nthPrimeResponse(prime))
//        }
//    }
//}]
