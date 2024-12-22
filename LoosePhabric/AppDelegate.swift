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
                print("pasteboard changed", self.lastChangeCount, self.pasteboard.changeCount)
                self.lastChangeCount = self.pasteboard.changeCount
                self.onPasteboardChanged()
            }
        }
    }

    func onPasteboardChanged() {
        guard let items = pasteboard.pasteboardItems else { return }
        guard let item = items.first else { return }
        guard let plain = item.string(forType: .string) else { return }

        if fetchPhabricatorTitleAndSetLink(text: plain) { return }
        if fetchGerritTitleAndSetLink(text: plain) { return }
    }

    func fetchPhabricatorTitleAndSetLink(text: String) -> Bool {
        // T12345 or T12345#54321 or https://phabricator.wikimedia.org/T12345#54321
        if !UserDefaults.standard.bool(forKey: "phabricator") {
            return false
        }
        let phabTicketPattern = /T\d+(?:#\d+)?/
        let urlString: String
        let ticket: String
        if (text.wholeMatch(of: phabTicketPattern) != nil) {
            urlString = "https://phabricator.wikimedia.org/\(text)"
            ticket = text
        } else if let url = URL(string: text), url.host == "phabricator.wikimedia.org" && url.pathComponents.count == 2 && (url.lastPathComponent.wholeMatch(of: phabTicketPattern) != nil) {
            // Note to self: pathComponents will be ["/", "T12345"]
            urlString = url.absoluteString
            if url.fragment != nil && url.fragment!.isNumeric {
                ticket = url.lastPathComponent + "#" + url.fragment!
            } else {
                ticket = url.lastPathComponent
            }
        } else {
            return false;
        }

        if UserDefaults.standard.bool(forKey: "expandTitles") {
            guard let url = URL(string: urlString) else { return false }
            let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                guard let data = data, error == nil else { return }
                if let htmlString = String(data: data, encoding: .utf8),
                   let titleRange = htmlString.range(of: "<title>")?.upperBound,
                   let titleEndRange = htmlString.range(of: "</title>", range: titleRange..<htmlString.endIndex)?.lowerBound {
                    var title = String(htmlString[titleRange..<titleEndRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    title = self.cleanUpPhabricatorTitle(title: title)
                    DispatchQueue.main.async {
                        self.setLinkToPasteboard(text: "\(ticket): \(title)", url: urlString)
                    }
                }
            }

            task.resume()
        } else {
            setLinkToPasteboard(text: ticket, url: urlString)
        }
        return true
    }

    func fetchGerritTitleAndSetLink(text: String) -> Bool {
        // Extract project name and change number from the input
        // e.g. https://gerrit.wikimedia.org/r/c/mediawiki/extensions/VisualEditor/+/1010703/20
        // or https://gerrit.wikimedia.org/r/1047469
        // or If317f991a4782bbc980d3923178799e1c67ebaa8
        if !UserDefaults.standard.bool(forKey: "gerrit") {
            return false
        }

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
                        let subject = jsonResponse["subject"] as? String,
                        let officialID = jsonResponse["id"] as? String
                    {
                        let title = "\(subject) (\(officialID))"
                        DispatchQueue.main.async {
                            self.setLinkToPasteboard(text: title.removingPercentEncoding ?? title, url: url.absoluteString)
                        }
                    }
                } catch {
                    print("Error parsing JSON response: \(error)")
                    print("JSON string: \(jsonString)")
                }
            }

            task.resume()
        } else {
            self.setLinkToPasteboard(text: changeID.removingPercentEncoding ?? changeID, url: url.absoluteString)
        }
        return true
    }

    func cleanUpPhabricatorTitle(title: String) -> String {
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

    func setLinkToPasteboard(text: String, url: String) {
        // We can be confident that the original exists, because it's checked in onPasteboardChanged
        let original = pasteboard.pasteboardItems!.first!.string(forType: .string) ?? text
        var htmlSafeText = text
        if !htmlSafeText.contains("&[^;]+;") {
            htmlSafeText = htmlSafeText.replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of:">", with: "&gt;");
            print("Cleaned text", htmlSafeText)
        }
        pasteboard.clearContents()
        // HTML because it's needed for pasting into Google Docs or similar locations
        pasteboard.setString("<a href=\"\(url)\">\(htmlSafeText)</a>", forType: .html)
        // RTF
        let attributedString = NSAttributedString(string: text, attributes: [.link: url])
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
        pasteboard.setString(url, forType: .URL)

        // Avoid looping
        self.lastChangeCount += 1
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        nc.removeObserver(self)
        timer.invalidate()
    }
}

extension String {
    var htmlDecoded: String {
        let decoded = try? NSAttributedString(data: Data(utf8), options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ], documentAttributes: nil).string

        return decoded ?? self
    }

    var isNumeric: Bool {
        let digits = CharacterSet.decimalDigits
        let stringSet = CharacterSet(charactersIn: self)

        return digits.isSuperset(of: stringSet)
    }
}

