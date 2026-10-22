//
//  Conduit.swift
//  LoosePhabric
//

import Foundation

enum ConduitError: Error, LocalizedError {
    case transport(String)
    case api(code: String, info: String?)
    case decode

    var errorDescription: String? {
        switch self {
        case .transport(let message): return message
        case .api(let code, let info): return info ?? code
        case .decode: return "Unexpected response from Phabricator"
        }
    }
}

// Client for the Phabricator Conduit API, with the token of the user.
enum Conduit {
    static let baseURL = "https://phabricator.wikimedia.org/api/"

    static func call<T: Decodable & Sendable>(
        _ method: String,
        token: String,
        params: [(String, String)],
        as type: T.Type,
        completion: @escaping @Sendable (Result<T, ConduitError>) -> Void
    ) {
        guard let url = URL(string: baseURL + method) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode([("api.token", token)] + params).data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                completion(.failure(.transport(error?.localizedDescription ?? "Unknown error")))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.transport("Non-200 status response")))
                return
            }
            // Conduit sends API errors with a 200 status, so examine error_code.
            if let status = try? JSONDecoder().decode(ConduitStatus.self, from: data), let code = status.errorCode {
                completion(.failure(.api(code: code, info: status.errorInfo)))
                return
            }
            guard let decoded = try? JSONDecoder().decode(ConduitResponse<T>.self, from: data) else {
                completion(.failure(.decode))
                return
            }
            completion(.success(decoded.result))
        }

        task.resume()
    }

    static func formEncode(_ params: [(String, String)]) -> String {
        // Do not use urlQueryAllowed: it keeps "+" and "&", which are special in a form body.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        func encode(_ s: String) -> String {
            return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
        }
        return params.map { "\(encode($0.0))=\(encode($0.1))" }.joined(separator: "&")
    }
}

private struct ConduitStatus: Decodable {
    let errorCode: String?
    let errorInfo: String?

    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case errorInfo = "error_info"
    }
}

private struct ConduitResponse<T: Decodable>: Decodable {
    let result: T
}
