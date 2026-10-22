//
//  GithubHandler.swift
//  LoosePhabric
//

import Foundation

final class GithubHandler: BaseHandler, Sendable {
    let defaultsKey: String = "github"

    // "closed" is a closed PR that was not merged, or an issue that was not completed.
    let statusMap: [String: String] = [
        "merged": "✅",
        "completed": "✅",
        "closed": "❌",
    ]

    func handle(_ text: String) -> Bool {
        // https://github.com/wikimedia/eslint-config-wikimedia/pull/666
        // https://github.com/wikimedia/eslint-config-wikimedia/pull/666/files
        // https://github.com/wikimedia/eslint-config-wikimedia/issues/563
        let pattern = #/\/(?<repo>[^\/]+\/[^\/]+)\/(?:pull|issues)\/(?<number>\d+)(?:\/.*)?/#
        guard let url = URL(string: text), url.host == "github.com",
              let match = url.path().wholeMatch(of: pattern) else {
            return false
        }

        setPasteboard(text: "\(match.repo)#\(match.number)", url: url.absoluteString)

        return true
    }

    func fetchTitleAndSetToPasteboard(text: String, urlString: String, changeCount: Int) {
        // The issues API also returns pull requests, so one request covers both.
        let parts = text.split(separator: "#")
        guard parts.count == 2,
              let url = URL(string: "https://api.github.com/repos/\(parts[0])/issues/\(parts[1])") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            // Private repositories give 404. Unauthenticated requests are rate-limited, which gives 403 or 429.
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Non-200 status response")
                return
            }
            guard let issue = try? JSONDecoder().decode(GithubIssue.self, from: data) else {
                print("Could not decode GitHub response")
                return
            }
            let title = self.decorateTitle(issue.title, issue.status)
            DispatchQueue.main.async {
                self.setLinkToPasteboard(text: "\(title) (\(text))", url: urlString, changeCount: changeCount)
            }
        }

        task.resume()
    }
}

struct GithubIssue: Decodable {
    struct PullRequest: Decodable {
        let mergedAt: String?

        enum CodingKeys: String, CodingKey {
            case mergedAt = "merged_at"
        }
    }

    let title: String
    let state: String
    let stateReason: String?
    let pullRequest: PullRequest?

    enum CodingKeys: String, CodingKey {
        case title
        case state
        case stateReason = "state_reason"
        case pullRequest = "pull_request"
    }

    var status: String {
        if state != "closed" {
            return state
        }
        if let pullRequest {
            return pullRequest.mergedAt != nil ? "merged" : "closed"
        }
        // Older closed issues have no state_reason. Most of them were completed.
        return (stateReason ?? "completed") == "completed" ? "completed" : "closed"
    }
}
