//
//  PhabricatorHandler.swift
//  LoosePhabric
//
//  Created by David Lynch on 1/24/25.
//

import Foundation

final class PhabricatorHandler: BaseHandler, Sendable {
    let defaultsKey: String = "phabricator"

    let statusMap: [String: String] = [
        //"open": "🔵",
        "closed": "✅",
    ]

    func handle(_ text: String) -> Bool {
        // T12345 or T12345#54321 or https://phabricator.wikimedia.org/T12345#54321

        // T tickets, P pastes, D code reviews, M mocks, E events, F files
        // rABCD for repositories also exists
        // .ignoresCase() could make sense
        let phabObjectPattern = /[TPDMEF]\d+(?:#\d+)?/
        let urlString: String
        let objectName: String
        if (text.wholeMatch(of: phabObjectPattern) != nil) {
            urlString = "https://phabricator.wikimedia.org/\(text)"
            objectName = text
        } else if let url = URL(string: text), url.host == "phabricator.wikimedia.org" && url.pathComponents.count == 2 && (url.lastPathComponent.wholeMatch(of: phabObjectPattern) != nil) {
            // Note to self: pathComponents will be ["/", "T12345"]
            urlString = url.absoluteString
            if url.fragment != nil && url.fragment!.isNumeric {
                objectName = url.lastPathComponent + "#" + url.fragment!
            } else {
                objectName = url.lastPathComponent
            }
        } else {
            return false;
        }

        setPasteboard(text: objectName, url: urlString)

        return true
    }

    func fetchTitleAndSetToPasteboard(text: String, urlString: String) {
        // First we're going to try using phabroxy
        guard let url = URL(string: "https://phabroxy.toolforge.org/lookup/\(text)") else { return }
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                self.fallbackHTMLFetch(objectName: text, urlString: urlString)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Non-200 status response")
                self.fallbackHTMLFetch(objectName: text, urlString: urlString)
                return
            }
            print("API response: \(String(data: data, encoding: .utf8) ?? "UNENCODABLE")")
            if let decoded = try? JSONDecoder().decode(PhabroxyResponse.self, from: data) {
                var fullName = decoded.fullName
                var uri = decoded.uri
                if urlString.contains("#") {
                    let comment = urlString.split(separator: "#").last ?? ""
                    fullName = fullName.replacingOccurrences(of: "\(decoded.name)", with: "\(decoded.name)#\(comment)")
                    uri = uri + "#\(comment)"
                }
                if self.showStatus && (self.statusMap[decoded.status] != nil) {
                    fullName = "\(self.statusMap[decoded.status] ?? "")\(fullName)"
                }
                DispatchQueue.main.async {
                    self.setLinkToPasteboard(text: fullName, url: uri)
                }
            } else {
                self.fallbackHTMLFetch(objectName: text, urlString: urlString)
            }
        }

        task.resume()
    }

    func fallbackHTMLFetch(objectName: String, urlString: String) {
        print("Falling back to direct phabricator URL fetch")
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
                var title = String(htmlString[titleRange..<titleEndRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                title = self.cleanUpHTMLTitle(title: title)
                // Specific guard against a 404/security issue:
                if title == "Login" && htmlString.contains(/class="auth-custom-message"/) {
                    print("Page required login")
                    return
                }
                DispatchQueue.main.async {
                    self.setLinkToPasteboard(text: "\(objectName): \(title)", url: urlString)
                }
            }
        }

        task.resume()
    }

    func cleanUpHTMLTitle(title: String) -> String {
        // Remove the leading "⚓ " and any other unwanted parts from the title
        var cleanedTitle = title
        if cleanedTitle.hasPrefix("⚓ ") {
            cleanedTitle.removeFirst(2)
        }
        // Ensure the task ID is included and formatted correctly
        if let range = cleanedTitle.range(of: "T\\d+", options: .regularExpression) {
            // let taskID = cleanedTitle[range]
            cleanedTitle = "\(cleanedTitle[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        return cleanedTitle.htmlDecoded
    }
}

struct PhabroxyResponse: Decodable {
    let fullName: String
    let name: String
    let phid: String
    let status: String
    let type: String
    let typeName: String
    let uri: String
}
