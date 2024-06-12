//
//  LoosePhabricApp.swift
//  LoosePhabric
//
//  Created by David Lynch on 6/7/24.
//

import SwiftUI
import LaunchAtLogin

@main
struct LoosePhabricApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("T", systemImage: "tray.and.arrow.down") {
            AppMenu()
        }
        Settings {
            SettingsView()
        }
    }
}

struct AppMenu: View {
    var body: some View {
        Label("LoosePhabric", systemImage: "book")
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
        Divider()
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }.keyboardShortcut("q")
    }
}

struct SettingsView: View {
    @AppStorage("expandTitles") private var expandTitles: Bool = true
    @AppStorage("phabricator") private var phabricator: Bool = true
    @AppStorage("gerrit") private var gerrit: Bool = true

    var body: some View {
        Form {
            Toggle("Expand to include titles", isOn: $expandTitles)
            Toggle("Watch for Phabricator", isOn: $phabricator)
            Toggle("Watch for Gerrit", isOn: $gerrit)
            LaunchAtLogin.Toggle()
        }
        .padding(20)
        .frame(width: 350, height: 100)
    }
}
