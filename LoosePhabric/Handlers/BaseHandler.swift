//
//  PasteHandler.swift
//  LoosePhabric
//
//  Created by David Lynch on 1/24/25.
//

import Foundation
import AppKit

protocol BaseHandler {
    var defaultsKey: String { get }
    func handle(_ text: String) -> Bool
    func fetchTitleAndSetToPasteboard(text: String, urlString: String)
}

extension BaseHandler {
    func enabled() -> Bool {
        return UserDefaults.standard.bool(forKey: self.defaultsKey)
    }

    var expand: Bool {
        return UserDefaults.standard.bool(forKey: "expandTitles")
    }

    var showStatus: Bool {
        return UserDefaults.standard.bool(forKey: "showStatus")
    }

    func setPasteboard(text: String, url: String) {
        if self.expand {
            fetchTitleAndSetToPasteboard(text: text, urlString: url)
        } else {
            setLinkToPasteboard(text: text, url: url)
        }
    }

    func setLinkToPasteboard(text: String, url: String) {
        print("Setting pasteboard", text, url)
        let pasteboard: NSPasteboard = .general

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

        NotificationCenter.default.post(name: Notification.Name("PasteboardSet"), object: nil)
    }
}
