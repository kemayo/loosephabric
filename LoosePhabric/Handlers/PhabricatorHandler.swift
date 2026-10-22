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
        // Bare IDs need 3 or more digits, so that short codes like P2 (priority) or F5 (key) are not changed.
        let bareObjectPattern = /[TPDMEF]\d{3,}(?:#\d+)?/
        let urlString: String
        let objectName: String
        if (text.wholeMatch(of: bareObjectPattern) != nil) {
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

    func fetchTitleAndSetToPasteboard(text: String, urlString: String, changeCount: Int) {
        if let token = Keychain.get(Keychain.phabricatorToken), !token.isEmpty {
            conduitFetch(text: text, urlString: urlString, changeCount: changeCount, token: token)
        } else {
            phabroxyFetch(text: text, urlString: urlString, changeCount: changeCount)
        }
    }

    func phabroxyFetch(text: String, urlString: String, changeCount: Int) {
        guard let url = URL(string: "https://phabroxy.toolforge.org/lookup/\(text)") else { return }
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                self.fallbackHTMLFetch(objectName: text, urlString: urlString, changeCount: changeCount)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Non-200 status response")
                self.fallbackHTMLFetch(objectName: text, urlString: urlString, changeCount: changeCount)
                return
            }
            print("API response: \(String(data: data, encoding: .utf8) ?? "UNENCODABLE")")
            if let decoded = try? JSONDecoder().decode(PhabroxyResponse.self, from: data) {
                // Phabroxy cannot see restricted objects, so they never get to this point.
                self.setLookupToPasteboard(decoded, restricted: false, urlString: urlString, changeCount: changeCount)
            } else {
                self.fallbackHTMLFetch(objectName: text, urlString: urlString, changeCount: changeCount)
            }
        }

        task.resume()
    }

    func conduitFetch(text: String, urlString: String, changeCount: Int, token: String) {
        // The text can include a comment anchor, as in "T12345#54321". Conduit needs only the object name.
        let name = String(text.split(separator: "#").first ?? "")
        // Do not fall back to phabroxy: a user with a token can prefer not to send requests through it.
        Conduit.call("phid.lookup", token: token, params: [("names[0]", name)], as: [String: PhabroxyResponse].self) { result in
            guard case .success(let objects) = result, let object = objects[name] else {
                if case .failure(let error) = result {
                    print("Conduit phid.lookup failed: \(error.localizedDescription)")
                }
                self.fallbackHTMLFetch(objectName: text, urlString: urlString, changeCount: changeCount)
                return
            }
            guard object.type == "TASK" else {
                self.setLookupToPasteboard(object, restricted: false, urlString: urlString, changeCount: changeCount)
                return
            }
            self.isRestrictedTask(phid: object.phid, token: token) { restricted in
                self.setLookupToPasteboard(object, restricted: restricted, urlString: urlString, changeCount: changeCount)
            }
        }
    }

    // A task is restricted when not everyone can view it.
    func isRestrictedTask(phid: String, token: String, completion: @escaping @Sendable (Bool) -> Void) {
        Conduit.call("maniphest.search", token: token, params: [("constraints[phids][0]", phid)], as: ManiphestSearchResult.self) { result in
            guard case .success(let search) = result, let item = search.data.first else {
                // If the policy is unknown, mark the task as restricted. A false mark is safer than a leaked title.
                print("Could not get task policy")
                completion(true)
                return
            }
            completion(item.fields.policy.view != "public")
        }
    }

    func setLookupToPasteboard(_ decoded: PhabroxyResponse, restricted: Bool, urlString: String, changeCount: Int) {
        var fullName = decoded.fullName
        var uri = decoded.uri
        if urlString.contains("#") {
            let comment = urlString.split(separator: "#").last ?? ""
            fullName = fullName.replacingOccurrences(of: "\(decoded.name)", with: "\(decoded.name)#\(comment)")
            uri = uri + "#\(comment)"
        }
        fullName = self.decorateTitle(fullName, decoded.status)
        // Always mark restricted tasks, so that the user sees the title is not public before they paste it.
        if restricted {
            fullName = "🔒 \(fullName)"
        }
        DispatchQueue.main.async {
            self.setLinkToPasteboard(text: fullName, url: uri, changeCount: changeCount)
        }
    }

    func fallbackHTMLFetch(objectName: String, urlString: String, changeCount: Int) {
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
                let rawTitle = String(htmlString[titleRange..<titleEndRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let needsLogin = htmlString.contains(/class="auth-custom-message"/)
                DispatchQueue.main.async {
                    let title = self.cleanUpHTMLTitle(title: rawTitle)
                    // Specific guard against a 404/security issue:
                    if title == "Login" && needsLogin {
                        print("Page required login")
                        return
                    }
                    self.setLinkToPasteboard(text: "\(objectName): \(title)", url: urlString, changeCount: changeCount)
                }
            }
        }

        task.resume()
    }

    @MainActor
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

struct ManiphestSearchResult: Decodable {
    struct Item: Decodable {
        struct Fields: Decodable {
            struct Policy: Decodable {
                let view: String
            }
            let policy: Policy
        }
        let fields: Fields
    }
    let data: [Item]
}
