//
//  LoosePhabricPasteboardController.swift
//  LoosePhabric
//
//  Created by David Lynch on 1/24/25.
//

import Foundation
import AppKit

class PasteboardController {
    var timer: Timer!
    let pasteboard: NSPasteboard = .general
    var lastChangeCount: Int = 0
    var handlers: [BaseHandler] = []

    init () {
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(checkPasteboard), userInfo: nil, repeats: true)
        NotificationCenter.default.addObserver(self, selector: #selector(onPasteboardSet), name: Notification.Name("PasteboardSet"), object: nil)
    }

    @objc func checkPasteboard() {
        if self.lastChangeCount != self.pasteboard.changeCount {
            print("!pasteboard changed!", self.lastChangeCount, self.pasteboard.changeCount)
            self.lastChangeCount = self.pasteboard.changeCount
            self.onPasteboardChanged()
        }
    }

    func onPasteboardChanged() {
        guard let items = pasteboard.pasteboardItems else { return }
        guard let item = items.first else { return }
        guard let plain = item.string(forType: .string) else { return }

        for handler in handlers {
            if handler.enabled() && handler.handle(plain) {
                return
            }
        }
    }

    @objc func onPasteboardSet() {
        // avoid endlessly processing the same value
        self.lastChangeCount += 1
    }

    func registerHandler(_ handler: BaseHandler) {
        handlers.append(handler)
    }
}
