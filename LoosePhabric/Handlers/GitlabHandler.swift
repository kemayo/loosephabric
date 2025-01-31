//
//  GitlabHandler.swift
//  LoosePhabric
//
//  Created by David Lynch on 1/24/25.
//

import Foundation

final class GitlabHandler: BaseHandler, Sendable {
    let defaultsKey: String = "gitlab"

    func handle(_ text: String) -> Bool {
        // https://gitlab.wikimedia.org/repos/mediawiki/services/ipoid/-/merge_requests/253 (merged)
        // https://gitlab.wikimedia.org/repos/mediawiki/services/ipoid/-/merge_requests/254 (closed)
        let mergePattern = #//repos/mediawiki/(?<repo>.+)/-/merge_requests/(?<reqid>\d+)/#
        let urlString: String
        let output: String
        if let url = URL(string: text), url.host == "gitlab.wikimedia.org" {
            if let match = url.path().wholeMatch(of: mergePattern) {
                // Note to self: pathComponents will be ["/", "T12345"]
                urlString = url.absoluteString
                output = "\(match.repo)~\(match.reqid)"
            } else {
                return false
            }
        } else {
            return false
        }

        setPasteboard(text: output, url: urlString)

        return true
    }

    func fetchTitleAndSetToPasteboard(text: String, urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Non-200 status response")
                return
            }

            if let htmlString = String(data: data, encoding: .utf8),
               let titleRange = htmlString.range(of: "<title>")?.upperBound,
               let titleEndRange = htmlString.range(of: "</title>", range: titleRange..<htmlString.endIndex)?.lowerBound {
                var title = String(htmlString[titleRange..<titleEndRange]).trimmingCharacters(in: .whitespacesAndNewlines).htmlDecoded
                if let match = title.wholeMatch(of: #/(?<title>.+) \(!\d+\) ·.+/#) {
                    title = "\(match.title)"
                }
                if self.showStatus {
                    if htmlString.contains("data-state=\"merged\"") {
                        title = "✅" + title
                    } else if htmlString.contains("data-state=\"closed\"") {
                        title = "❌" + title
                    }
                }
                DispatchQueue.main.async {
                    self.setLinkToPasteboard(text: "\(title) (\(text))", url: urlString)
                }
            }
        }

        task.resume()
    }
}
