//
//  AppDelegate.swift
//  LoosePhabric
//
//  Created by David Lynch on 6/7/24.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var timer: Timer!
    let pasteboard: NSPasteboard = .general
    var lastChangeCount: Int = 0

    var lastInputValue: String?
    var lastSetValue: String?

    let nc = NotificationCenter.default
    let publisher = NotificationCenter.default.publisher(for: Notification.Name("NSPasteboardDidChange"))

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { (t) in
            if self.lastChangeCount != self.pasteboard.changeCount {
                self.lastChangeCount = self.pasteboard.changeCount
                self.onPasteboardChanged()
            }
        }
    }

    func onPasteboardChanged() {
        guard let items = pasteboard.pasteboardItems else { return }
        guard let item = items.first else { return }
        guard let plain = item.string(forType: .string) else { return }
        
        if plain == lastInputValue || plain == lastSetValue { return }
        lastSetValue = nil
        lastInputValue = nil
        
        if  plain.wholeMatch(of: /T\d+(?:#\d+)?/) != nil {
            // T12345 or T12345#54321
            fetchTitleAndSetLink(text: plain)
        } else if let gerritURL = URL(string: plain), gerritURL.host == "gerrit.wikimedia.org" {
            fetchGerritTitleAndSetLink(url: gerritURL)
        }

    }

    func fetchTitleAndSetLink(text: String) {
        let urlString: String
        urlString = "https://phabricator.wikimedia.org/\(text)"

        guard let url = URL(string: urlString) else { return }

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data, error == nil else { return }
            if let htmlString = String(data: data, encoding: .utf8),
               let titleRange = htmlString.range(of: "<title>")?.upperBound,
               let titleEndRange = htmlString.range(of: "</title>", range: titleRange..<htmlString.endIndex)?.lowerBound {
                var title = String(htmlString[titleRange..<titleEndRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                title = self.cleanUpTitle(title: title)
                DispatchQueue.main.async {
                    self.setLinkToPasteboard(text: "\(text): \(title)", URL: urlString)
                }
            }
        }

        task.resume()
    }

    func fetchGerritTitleAndSetLink(url: URL) {
        // Extract project name and change number from the URL path
        let pathComponents = url.pathComponents
        guard let cIndex = pathComponents.firstIndex(of: "c"),
              let plusIndex = pathComponents.firstIndex(of: "+"),
              cIndex < plusIndex else { return }

        let projectNameComponents = pathComponents[cIndex+1..<plusIndex]
        let humanReadableProjectName = projectNameComponents.joined(separator: "/")
        let projectName = projectNameComponents.joined(separator: "%2F")
        let changeNumber = pathComponents[plusIndex+1]

        // Construct the Gerrit API URL using the correct change ID format
        let changeID = "\(projectName)~\(changeNumber)"
        let apiURLString = "https://gerrit.wikimedia.org/r/changes/\(changeID)"
        guard let apiURL = URL(string: apiURLString) else { return }

        let task = URLSession.shared.dataTask(with: apiURL) { (data, response, error) in
            guard let data = data, error == nil else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
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

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                   let subject = jsonResponse["subject"] as? String {
                    let title = "\(subject) (\(humanReadableProjectName)-\(changeNumber))"
                    DispatchQueue.main.async {
                        self.setLinkToPasteboard(text: title, URL: url.absoluteString)
                    }
                }
            } catch {
                print("Error parsing JSON response: \(error)")
                print("JSON string: \(jsonString)")
            }
        }

        task.resume()
    }

    func cleanUpTitle(title: String) -> String {
        // Remove the leading "⚓ " and any other unwanted parts from the title
        var cleanedTitle = title
        if cleanedTitle.hasPrefix("⚓ ") {
            cleanedTitle.removeFirst(2)
        }
        // Ensure the task ID is included and formatted correctly
        if let range = cleanedTitle.range(of: "T\\d+", options: .regularExpression) {
            let taskID = cleanedTitle[range]
            cleanedTitle = "\(cleanedTitle[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        return cleanedTitle
    }
    func setLinkToPasteboard(text: String, URL: String) {
        lastInputValue = text
        // Create an HTML string with a link
        let htmlString = "<a href=\"\(URL)\">\(text)</a>"
        // Convert HTML string to attributed string
        guard let attributedString = try? NSAttributedString(data: htmlString.data(using: .utf8)!,
                                                              options: [.documentType: NSAttributedString.DocumentType.html],
                                                              documentAttributes: nil) else {
            print("Error creating attributed string from HTML")
            return
        }
        pasteboard.clearContents()
         do {
             let htmlData = try attributedString.data(from: NSRange(location: 0, length: attributedString.length),
                                                      documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
             pasteboard.setData(htmlData, forType: .html)
         } catch {
             print("Error setting pasteboard data", error)
         }
        // Set plain text to pasteboard as a fallback
        pasteboard.setString(text, forType: .string)
        lastSetValue = text
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        nc.removeObserver(self)
        timer.invalidate()
    }
}
