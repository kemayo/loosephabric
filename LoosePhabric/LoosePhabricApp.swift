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
let PASTEBOARD_NOTIFICATION_IDENTIFIER = "LoosePhabric.PasteboardUpdated"
let PASTEBOARD_TYPE = NSPasteboard.PasteboardType(rawValue: "x-LoosePhabric")

// An agent app does not become active when its menu is used, so its windows open behind other apps.
// The cooperative NSApp.activate() from macOS 14 is often declined, so use the older call.
@MainActor
func activateApp() {
    NSApp.activate(ignoringOtherApps: true)
}

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
            "notify": true,
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
        MenuBarExtra {
            AppMenu(updater: updaterController.updater, updateStatus: userDriverDelegate)
        } label: {
            MenuBarIcon(updateStatus: userDriverDelegate)
        }
        Settings {
            SettingsView(updater: updaterController.updater, updateStatus: userDriverDelegate)
        }
    }
}

struct MenuBarIcon: View {
    @ObservedObject var updateStatus: SparkleUserDriverDelegate
    var body: some View {
        if updateStatus.pendingUpdateVersion == nil {
            Image(systemName: "tray.and.arrow.down")
        } else {
            Image(nsImage: Self.badgedIcon)
        }
    }

    // A MenuBarExtra label shows only one image, so draw the badge into it.
    @MainActor
    private static let badgedIcon: NSImage = {
        let view = Image(systemName: "tray.and.arrow.down")
            .font(.system(size: NSFont.menuBarFont(ofSize: 0).pointSize))
            .foregroundStyle(.black)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .frame(width: 6, height: 6)
                    // Erase a ring around the badge, so that it stays visible over the tray.
                    .background(Circle().frame(width: 9, height: 9).blendMode(.destinationOut))
            }
            .compositingGroup()
        let renderer = ImageRenderer(content: view)
        // The image is made once. 2x looks correct on Retina displays and scales down on others.
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage()
        // Template images follow the menu bar's light or dark appearance.
        image.isTemplate = true
        return image
    }()
}

// SettingsLink does not activate the app, so the window can open behind other apps.
@available(macOS 14.0, *)
struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        Button("Settings...") {
            activateApp()
            openSettings()
        }
    }
}

struct AppMenu: View {
    let updater: SPUUpdater
    @ObservedObject var updateStatus: SparkleUserDriverDelegate
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    var body: some View {
        Label("LoosePhabric \(appVersion ?? "")", systemImage: "book")
        if #available(macOS 14.0, *) {
            OpenSettingsButton()
        } else {
            Button("Settings...") {
                activateApp()
                if #available(macOS 13.0, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }
        }
        CheckForUpdatesView(updater: updater, updateStatus: updateStatus)
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

        NotificationCenter.default.addObserver(self, selector: #selector(onPasteboardSet), name: Notification.Name("PasteboardSet"), object: nil)
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
        let userInfo = response.notification.request.content.userInfo
        //print("Notification with userInfo: \(userInfo)")
        if response.notification.request.identifier == UPDATE_NOTIFICATION_IDENTIFIER && response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // show controller
            await handleUpdaterRequest()
        } else if response.notification.request.identifier == PASTEBOARD_NOTIFICATION_IDENTIFIER && response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let url = URL(string: userInfo["url"] as! String) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @MainActor
    func handleUpdaterRequest() {
        activateApp()
        updaterController?.checkForUpdates(nil)
    }

    @objc func onPasteboardSet(_ notification: NSNotification) {
        if !UserDefaults.standard.bool(forKey: "notify") {
            return
        }
        guard let userInfo = notification.userInfo else { return }
        let source = userInfo["source"] ?? "unknown"
        let url = userInfo["url"] ?? "unknown"
        let text = userInfo["text"] ?? "unknown"

        let content = UNMutableNotificationContent()
        content.title = "\(source) detected"
        content.body = "\(text)\n\(url)"
        content.userInfo = userInfo

        let request = UNNotificationRequest(identifier: PASTEBOARD_NOTIFICATION_IDENTIFIER, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

class SparkleUserDriverDelegate: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    // Set while a scheduled update waits for the user, to show it in the menu.
    @Published var pendingUpdateVersion: String?

    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        // Sparkle can show its window behind other apps, because macOS often declines its activation request.
        // Always use a notification and the menu instead.
        return false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !handleShowingUpdate else { return }
        if state.userInitiated { return }

        pendingUpdateVersion = update.displayVersionString

        let content = UNMutableNotificationContent()
        content.title = "New update available"
        content.body = "Version \(update.displayVersionString) is now available"

        let request = UNNotificationRequest(identifier: UPDATE_NOTIFICATION_IDENTIFIER, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        pendingUpdateVersion = nil
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [UPDATE_NOTIFICATION_IDENTIFIER])
    }

    func standardUserDriverWillFinishUpdateSession() {
        pendingUpdateVersion = nil
    }
}
