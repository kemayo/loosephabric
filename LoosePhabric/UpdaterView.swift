//
//  UpdaterView.swift
//  LoosePhabric
//
//  Created by David Lynch on 8/17/24.
//

import Foundation
import SwiftUI
import Sparkle


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
    @ObservedObject private var updateStatus: SparkleUserDriverDelegate
    private let updater: SPUUpdater

    init(updater: SPUUpdater, updateStatus: SparkleUserDriverDelegate) {
        self.updater = updater
        self.updateStatus = updateStatus

        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    // With a pending update, checkForUpdates shows that update again, so the label tells the user.
    private var label: String {
        if let version = updateStatus.pendingUpdateVersion {
            return "Update to version \(version)..."
        }
        return "Check for updates now..."
    }

    var body: some View {
        Button(label) {
            activateApp()
            updater.checkForUpdates()
        }
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

