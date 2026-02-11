//
//  LoosePhabricApp.swift
//  LoosePhabric
//
//  Created by David Lynch on 6/7/24.
//

import SwiftUI
import UserNotifications
import Sparkle

let UPDATE_NOTIFICATION_IDENTIFIER = "LoosePhabric.UpdateNotification"

@main
struct LoosePhabricApp: App {
    private let updaterController: SPUStandardUpdaterController
    private let userDriverDelegate = SparkleUserDriverDelegate()
    private let pasteboardController: PasteboardController

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate: AppDelegate

    init() {
        UserDefaults.standard.register(defaults: [
            "expandTitles": true,
            "showStatus": true,
            "phabricator": true,
            "gerrit": true,
            "gitlab": true,
        ])

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: userDriverDelegate
        )

        pasteboardController = PasteboardController()
        pasteboardController.registerHandler(PhabricatorHandler())
        pasteboardController.registerHandler(GerritHandler())
        pasteboardController.registerHandler(GitlabHandler())

        appDelegate.updaterController = updaterController
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

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
    }

    // foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        //let userInfo = response.notification.request.content.userInfo
        //print("Notification with userInfo: \(userInfo)")
        if response.notification.request.identifier == UPDATE_NOTIFICATION_IDENTIFIER && response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // show controller
            await handleUpdaterRequest()
        }
    }

    @MainActor
    func handleUpdaterRequest() {
        updaterController?.checkForUpdates(nil)
    }
}

class SparkleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        // If the app has a reasonable amount of focus, it can show the update dialog safely. If not, we want to show a notification.
        return immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !handleShowingUpdate else { return }
        if state.userInitiated { return }

        do {
            let content = UNMutableNotificationContent()
            content.title = "New update available"
            content.body = "Version \(update.displayVersionString) is now available"

            let request = UNNotificationRequest(identifier: UPDATE_NOTIFICATION_IDENTIFIER, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [UPDATE_NOTIFICATION_IDENTIFIER])
    }
}
