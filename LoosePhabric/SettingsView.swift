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
    let updater: SPUUpdater
    let updateStatus: SparkleUserDriverDelegate

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            PhabricatorSettingsView()
                .tabItem { Label("Phabricator", systemImage: "key") }
            UpdaterSettingsView(updater: updater, updateStatus: updateStatus)
                .tabItem { Label("Updates", systemImage: "arrow.down.circle") }
        }
        .frame(width: 450)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("expandTitles") private var expandTitles: Bool = true
    @AppStorage("showStatus") private var showStatus: Bool = true
    @AppStorage("phabricator") private var phabricator: Bool = true
    @AppStorage("gerrit") private var gerrit: Bool = true
    @AppStorage("gitlab") private var gitlab: Bool = true
    @AppStorage("github") private var github: Bool = true
    @AppStorage("notify") private var notify: Bool = true

    var body: some View {
        Form {
            Toggle("Expand to include titles", isOn: $expandTitles)
            Toggle("Show status if available", isOn: $showStatus)
            Toggle("Notify when a replacement occurs", isOn: $notify)
            Divider()
            Toggle("Watch for Phabricator", isOn: $phabricator)
            Toggle("Watch for Gerrit", isOn: $gerrit)
            Toggle("Watch for GitLab", isOn: $gitlab)
            Toggle("Watch for GitHub", isOn: $github)
            Divider()
            LaunchAtLogin.Toggle()
        }
        .padding(20)
    }
}

struct PhabricatorSettingsView: View {
    @AppStorage("maskRestrictedTitles") private var maskRestrictedTitles: Bool = false
    @State private var token: String = ""
    @State private var message: String = ""

    var body: some View {
        Form {
            Section {
                SecureField("API token", text: $token)
                    .onSubmit(save)
                HStack {
                    Link("Get a token", destination: URL(string: "https://phabricator.wikimedia.org/settings/panel/apitokens/")!)
                    Spacer()
                    Button("Clear", action: clear)
                    Button("Save", action: save)
                }
            } footer: {
                Text(message)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Hide titles of restricted tasks", isOn: $maskRestrictedTitles)
            } footer: {
                Text("Without a token, titles come from phabroxy.toolforge.org. With a token, they come directly from Phabricator, and include the tasks that your account can see. A 🔒 marks tasks that are not public. To link those tasks without their titles, hide them.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        // A grouped Form scrolls, so without this the Settings window can give it no height.
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            token = Keychain.get(Keychain.phabricatorToken) ?? ""
            message = token.isEmpty ? "Using phabroxy" : "Using your token"
        }
    }

    private func clear() {
        token = ""
        Keychain.delete(Keychain.phabricatorToken)
        message = "Using phabroxy"
    }

    private func save() {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            clear()
            return
        }
        token = trimmed
        guard Keychain.set(Keychain.phabricatorToken, trimmed) else {
            message = "Could not save the token to the keychain"
            return
        }
        message = "Checking token..."
        Conduit.call("user.whoami", token: trimmed, params: [], as: WhoAmI.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    message = "Saved. Using the token of \(user.userName)."
                case .failure(let error):
                    message = "Saved, but the check failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct WhoAmI: Decodable {
    let userName: String
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
                .onChange(of: automaticallyChecksForUpdates) { _, newValue in
                    updater.automaticallyChecksForUpdates = newValue
                }
            Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                .disabled(!automaticallyChecksForUpdates)
                .onChange(of: automaticallyDownloadsUpdates) { _, newValue in
                    updater.automaticallyDownloadsUpdates = newValue
                }
            CheckForUpdatesView(updater: updater, updateStatus: updateStatus)
        }
        .padding(20)
    }
}

#Preview {
    SettingsView(updater: SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil).updater, updateStatus: SparkleUserDriverDelegate())
}
