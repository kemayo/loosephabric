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
        
        if let match = plain.wholeMatch(of: /T\d+(?:#\d+)?/) {
            // T12345 or T12345#54321
            setLinkToPasteboard(text: plain, URL: "https://phabricator.wikimedia.org/\(plain)")
        }
    }
    
    func setLinkToPasteboard(text: String, URL: String) {
        lastInputValue = text
        let attributedString = NSAttributedString(string: text, attributes: [.link: URL])
        do {
            let rtf = try attributedString.data(from: NSMakeRange(0, attributedString.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtf])
            pasteboard.clearContents()
            pasteboard.setData(rtf, forType: .rtf)
            pasteboard.setString(text, forType: .string)
            lastSetValue = text
        } catch {
            print("Error setting pasteboard data", error)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        nc.removeObserver(self)
        timer.invalidate()
    }
}
