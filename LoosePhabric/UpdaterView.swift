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

