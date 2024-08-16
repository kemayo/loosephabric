//
//  LoosePhabricApp.swift
//  LoosePhabric
//
//  Created by David Lynch on 6/7/24.
//

import SwiftUI
import Sparkle
import LaunchAtLogin

@main
struct LoosePhabricApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var body: some Scene {
        MenuBarExtra("T", systemImage: "tray.and.arrow.down") {
            AppMenu(updater: updaterController.updater)
        }
        Settings {
            SettingsView()
            UpdaterSettingsView(updater: updaterController.updater)
        }
    }
}

struct AppMenu: View {
    private let updater: SPUUpdater
    init(updater: SPUUpdater) {
        self.updater = updater
    }
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
        CheckForUpdatesView(updater: updater)
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

// See: https://sparkle-project.org/documentation/programmatic-setup/

// publish when updates can be checked:
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

// show the check for updates menu item
// apparently needed as a distinct view for Monterey compat
struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater

        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for updates now...", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

struct UpdaterSettingsView: View {
    private let updater: SPUUpdater

    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool

    init(updater:SPUUpdater) {
        self.updater = updater
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }

    var body: some View {
        VStack {
            Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                .onChange(of: automaticallyChecksForUpdates) { newValue in
                    updater.automaticallyChecksForUpdates = newValue
                }
            Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                .disabled(!automaticallyChecksForUpdates)
                .onChange(of: automaticallyDownloadsUpdates) { newValue in
                    updater.automaticallyDownloadsUpdates = newValue
                }
            CheckForUpdatesView(updater: updater)
        }.padding()
    }
}
