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
        UserDefaults.standard.register(defaults: [
            "expandTitles": true,
            "phabricator": true,
            "gerrit": true,
        ])
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
        lastInputValue = plain

        if fetchPhabricatorTitleAndSetLink(text: plain) { return }
        if fetchGerritTitleAndSetLink(text: plain) { return }
    }

    func fetchPhabricatorTitleAndSetLink(text: String) -> Bool {
        // T12345 or T12345#54321
        if !UserDefaults.standard.bool(forKey: "phabricator") {
            return false
        }
        if text.wholeMatch(of: /T\d+(?:#\d+)?/) == nil {
            return false
        }
        let urlString: String
        urlString = "https://phabricator.wikimedia.org/\(text)"

        if UserDefaults.standard.bool(forKey: "expandTitles") {
            guard let url = URL(string: urlString) else { return false }
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
        } else {
            setLinkToPasteboard(text: text, URL: urlString)
        }
        return true
    }

    func fetchGerritTitleAndSetLink(text: String) -> Bool {
        // Extract project name and change number from the URL path
        // e.g. https://gerrit.wikimedia.org/r/c/mediawiki/extensions/VisualEditor/+/1010703/20
        if !UserDefaults.standard.bool(forKey: "gerrit") {
            return false
        }
        guard let url = URL(string: text) else { return false }
        if url.host != "gerrit.wikimedia.org" {
            return false
        }

        let pathComponents = url.pathComponents
        guard let cIndex = pathComponents.firstIndex(of: "c"),
              let plusIndex = pathComponents.firstIndex(of: "+"),
              cIndex < plusIndex else { return false }

        let projectNameComponents = pathComponents[cIndex+1..<plusIndex]
        let humanReadableProjectName = projectNameComponents.joined(separator: "/")
        let projectName = projectNameComponents.joined(separator: "%2F")
        let changeNumber = pathComponents[plusIndex+1]
        let changeID = "\(projectName)~\(changeNumber)"

        if UserDefaults.standard.bool(forKey: "expandTitles") {
            // Construct the Gerrit API URL using the correct change ID format
            let apiURLString = "https://gerrit.wikimedia.org/r/changes/\(changeID)"
            guard let apiURL = URL(string: apiURLString) else { return false }

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
        } else {
            self.setLinkToPasteboard(text: "\(humanReadableProjectName)~\(changeNumber)", URL: url.absoluteString)
        }
        return true
    }

    func cleanUpTitle(title: String) -> String {
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
        return cleanedTitle
    }

    func setLinkToPasteboard(text: String, URL: String) {
        // We can be confident that the original exists, because it's checked in onPasteboardChanged
        let original = pasteboard.pasteboardItems!.first!.string(forType: .string) ?? text
        pasteboard.clearContents()
        // HTML because it's needed for pasting into Google Docs or similar locations
        pasteboard.setString("<a href=\"\(URL)\">\(text)</a>", forType: .html)
        let attributedString = NSAttributedString(string: text, attributes: [.link: URL])
        do {
            let rtf = try attributedString.data(from: NSMakeRange(0, attributedString.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtf])
            pasteboard.setData(rtf, forType: .rtf)
        } catch {
            print("Error setting rtf pasteboard data", error)
        }
        // Set the original plain text to pasteboard as a fallback
        // If we're transforming from a URL, this will mean it still works to paste into browser URL bars
        pasteboard.setString(original, forType: .string)
        // For completeness:
        pasteboard.setString(URL, forType: .URL)
        lastSetValue = text
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        nc.removeObserver(self)
        timer.invalidate()
    }
}
