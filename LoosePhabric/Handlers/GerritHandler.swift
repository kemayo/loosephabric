//
//  GerritHandler.swift
//  LoosePhabric
//
//  Created by David Lynch on 1/24/25.
//

import Foundation

final class GerritHandler: BaseHandler, Sendable {
    let defaultsKey: String = "gerrit"
    
    func handle(_ text: String) -> Bool {
        // Extract project name and change number from the input
        // e.g. https://gerrit.wikimedia.org/r/c/mediawiki/extensions/VisualEditor/+/1010703/20
        // or https://gerrit.wikimedia.org/r/1047469
        // or If317f991a4782bbc980d3923178799e1c67ebaa8
        let changeID: String
        let url: URL

        if text.wholeMatch(of: /I[a-fA-F0-9]{40}/) != nil {
            // This is just a Change-Id like If317f991a4782bbc980d3923178799e1c67ebaa8
            changeID = text
            url = URL(string: "https://gerrit.wikimedia.org/r/q/\(changeID)")!
        } else {
            guard let maybeurl = URL(string: text) else { return false }
            url = maybeurl
            if url.host != "gerrit.wikimedia.org" {
                return false
            }

            let pathComponents = url.pathComponents

            if url.path().wholeMatch(of: /\/r\/\d+/) != nil {
                // e.g. https://gerrit.wikimedia.org/r/1047469
                changeID = pathComponents.last!
            } else {
                guard let cIndex = pathComponents.firstIndex(of: "c"),
                      let plusIndex = pathComponents.firstIndex(of: "+"),
                      cIndex < plusIndex else { return false }
                let projectNameComponents = pathComponents[cIndex+1..<plusIndex]
                let projectName = projectNameComponents.joined(separator: "%2F")
                let changeNumber = pathComponents[plusIndex+1]
                changeID = "\(projectName)~\(changeNumber)"
            }
        }

        setPasteboard(text: changeID, url: url.absoluteString)

        return true
    }

    func fetchTitleAndSetToPasteboard(text: String, urlString: String) {
        let changeID = text
        // Construct the Gerrit API URL using the correct change ID format
        let apiURLString = "https://gerrit.wikimedia.org/r/changes/\(changeID)"
        guard let apiURL = URL(string: apiURLString) else { return }

        let task = URLSession.shared.dataTask(with: apiURL) { (data, response, error) in
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Non-200 status response")
                return
            }

            // Convert data to string and remove Gerrit's XSSI protection prefix
            let dataString = String(data: data, encoding: .utf8)
            guard let jsonString = dataString?.replacingOccurrences(of: ")]}'", with: "").trimmingCharacters(in: .whitespacesAndNewlines) else {
                print("Error converting data to string")
                return
            }
            guard let jsonData = jsonString.data(using: .utf8) else {
                print("Error converting cleaned JSON string to Data")
                return
            }

            // Debugging: Print the cleaned JSON string
            print("Cleaned JSON string: \(jsonString)")

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSSSS"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            if let decoded = try? decoder.decode(GerritResponse.self, from: jsonData) {
                let title = "\(decoded.subject) (\(decoded.id))"
                DispatchQueue.main.async {
                    self.setLinkToPasteboard(text: title.removingPercentEncoding ?? title, url: urlString)
                }
            } else {
                print("Decoding failed")
            }
        }

        task.resume()
    }
}

// Note, there's still missing fields from this
struct GerritResponse: Decodable {
    let id: String
    let changeId: String
    let subject: String
    let status: String
    let branch: String
    let topic: String
    let tripletId: String
    let project: String
    let created: Date
    let updated: Date
    let submitted: Date?
    let insertions: Int
    let deletions: Int
    let currentRevisionNumber: Int
    let hashtags: [String]?
}

