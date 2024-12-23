//
//  SettingsView.swift
//  LoosePhabric
//
//  Created by David Lynch on 8/17/24.
//

import Foundation
import SwiftUI
import Sparkle
import LaunchAtLogin


struct SettingsView: View {
    @AppStorage("expandTitles") private var expandTitles: Bool = true
    @AppStorage("phabricator") private var phabricator: Bool = true
    @AppStorage("gerrit") private var gerrit: Bool = true
    @AppStorage("gitlab") private var gitlab: Bool = true

    let updater: SPUUpdater

    var body: some View {
        Form {
            Toggle("Expand to include titles", isOn: $expandTitles)
            Toggle("Watch for Phabricator", isOn: $phabricator)
            Toggle("Watch for Gerrit", isOn: $gerrit)
            Toggle("Watch for Gitlab", isOn: $gitlab)
            LaunchAtLogin.Toggle()

            UpdaterSettingsView(updater: updater)
        }
        .padding(20)
        .frame(width: 350, height: 250)
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

#Preview {
    SettingsView(updater: SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil).updater)
}
