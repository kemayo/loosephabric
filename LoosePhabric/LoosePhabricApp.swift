//
//  LoosePhabricApp.swift
//  LoosePhabric
//
//  Created by David Lynch on 6/7/24.
//

import SwiftUI
import Sparkle

@main
struct LoosePhabricApp: App {
    private let updaterController: SPUStandardUpdaterController
    private let pasteboardController: PasteboardController

    init() {
        UserDefaults.standard.register(defaults: [
            "expandTitles": true,
            "showStatus": true,
            "phabricator": true,
            "gerrit": true,
            "gitlab": true,
        ])

        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        pasteboardController = PasteboardController()
        pasteboardController.registerHandler(PhabricatorHandler())
        pasteboardController.registerHandler(GerritHandler())
        pasteboardController.registerHandler(GitlabHandler())
    }

    var body: some Scene {
        MenuBarExtra("T", systemImage: "tray.and.arrow.down") {
            AppMenu(updater: updaterController.updater)
        }
        Settings {
            SettingsView(updater: updaterController.updater)
        }
    }
}

struct AppMenu: View {
    let updater: SPUUpdater
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    var body: some View {
        Label("LoosePhabric \(appVersion ?? "")", systemImage: "book")
        if #available(macOS 14.0, *) {
            SettingsLink()
        } else {
            Button("Settings...") {
                if #available(macOS 13.0, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }
        }
        CheckForUpdatesView(updater: updater)
        Divider()
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }.keyboardShortcut("q")
    }
}
