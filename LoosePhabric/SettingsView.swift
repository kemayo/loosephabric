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
    @AppStorage("showStatus") private var showStatus: Bool = true
    @AppStorage("phabricator") private var phabricator: Bool = true
    @AppStorage("gerrit") private var gerrit: Bool = true
    @AppStorage("gitlab") private var gitlab: Bool = true
    @AppStorage("notify") private var notify: Bool = true

    let updater: SPUUpdater
    let updateStatus: SparkleUserDriverDelegate

    var body: some View {
        Form {
            Toggle("Expand to include titles", isOn: $expandTitles)
            Toggle("Show status if available", isOn: $showStatus)
            Toggle("Notify when a replacement occurs", isOn: $notify)
            Divider()
            Toggle("Watch for Phabricator", isOn: $phabricator)
            Toggle("Watch for Gerrit", isOn: $gerrit)
            Toggle("Watch for Gitlab", isOn: $gitlab)
            Divider()
            LaunchAtLogin.Toggle()

            UpdaterSettingsView(updater: updater, updateStatus: updateStatus)
        }
        .padding(20)
        .frame(width: 350)
    }
}

struct UpdaterSettingsView: View {
    private let updater: SPUUpdater
    private let updateStatus: SparkleUserDriverDelegate

    @State private var automaticallyChecksForUpdates: Bool
    @State private var automaticallyDownloadsUpdates: Bool

    init(updater: SPUUpdater, updateStatus: SparkleUserDriverDelegate) {
        self.updater = updater
        self.updateStatus = updateStatus
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
            CheckForUpdatesView(updater: updater, updateStatus: updateStatus)
        }.padding()
    }
}

#Preview {
    SettingsView(updater: SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil).updater, updateStatus: SparkleUserDriverDelegate())
}
