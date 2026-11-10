//
//  CompanionApp.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import UIKit
import UserNotifications

enum CompanionTab: Hashable {
    case pair
    case alerts
    case photos
}

@MainActor
@Observable
final class CompanionNavigation {
    var selectedTab: CompanionTab = .pair
}

/// DEBUG screenshot states, picked by the `LW_COMPANION_FIXTURE` launch variable.
enum CompanionFixture: String {
    case ready
    case denied
    case alerts
    case photos
    case photosUnavailable

    var deviceToken: Data? {
        self == .denied ? nil : Data((0 ..< 32).map { UInt8($0 * 7 & 0xFF) })
    }

    var alerts: [ReceivedAlert] {
        guard self == .alerts else { return [] }
        return [
            ReceivedAlert(id: "fixture-2", title: "Lock-Watcher", body: "USB device connected · 14:32", trigger: "usbConnected",
                          date: Date(timeIntervalSince1970: 1_793_021_520), latitude: 50.4501, longitude: 30.5234, ip: "203.0.113.7"),
            ReceivedAlert(id: "fixture-1", title: "Lock-Watcher", body: "Mac woke up · 09:05", trigger: "onWakeUp",
                          date: Date(timeIntervalSince1970: 1_793_001_900), latitude: nil, longitude: nil, ip: nil)
        ]
    }
}

/// Composition root, owned by the app delegate so APNs callbacks and the scene share one set of models.
@MainActor
final class CompanionContainer {
    let registration: PushRegistrationModel
    let inbox: AlertInbox
    let photos: CloudPhotoLibrary
    let navigation: CompanionNavigation
    let receiver: NotificationReceiver
    private let fixture: CompanionFixture?

    init() {
        let fixture = Self.launchFixture()
        let inbox = AlertInbox(store: fixture.map { InMemoryAlertStore(alerts: $0.alerts) as any AlertPersisting } ?? FileAlertStore.applicationSupport())
        let registrar: any RemoteNotificationRegistering = fixture.map { StubRemoteNotificationRegistrar(isAuthorized: $0 != .denied) }
            ?? LiveRemoteNotificationRegistrar()
        let navigation = CompanionNavigation()
        self.navigation = navigation
        self.fixture = fixture
        self.inbox = inbox
        photos = CloudPhotoLibrary(source: Self.photoSource(for: fixture))
        registration = PushRegistrationModel(registrar: registrar, configuration: .main())
        receiver = NotificationReceiver { [weak inbox] alerts, opened in
            inbox?.ingest(alerts)
            if opened {
                navigation.selectedTab = .alerts
            }
        }
        switch fixture {
        case .alerts: navigation.selectedTab = .alerts
        case .photos, .photosUnavailable: navigation.selectedTab = .photos
        case .ready, .denied, .none: break
        }
    }

    /// Re-registers on every activation because APNs may rotate the token, and pulls alerts delivered while the app was closed.
    /// The photo refresh runs beside the registration because the notification prompt can hold `start()` open indefinitely.
    func becameActive() async {
        async let photosRefreshed: Void = photos.refresh()
        await registration.start()
        if let token = fixture?.deviceToken {
            registration.didRegister(deviceToken: token)
        }
        if fixture == nil {
            await inbox.ingest(receiver.deliveredAlerts())
        }
        await photosRefreshed
    }

    private static func photoSource(for fixture: CompanionFixture?) -> any CloudPhotoSource {
        #if DEBUG
            if let fixture {
                return FixturePhotoSource(mode: fixture.photoMode)
            }
        #endif
        return ICloudPhotoSource()
    }

    private static func launchFixture() -> CompanionFixture? {
        #if DEBUG
            ProcessInfo.processInfo.environment["LW_COMPANION_FIXTURE"].flatMap(CompanionFixture.init(rawValue:))
        #else
            nil
        #endif
    }
}

struct LiveRemoteNotificationRegistrar: RemoteNotificationRegistering {
    func requestAuthorization() async -> Bool {
        await (try? UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    @MainActor
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}

@MainActor
final class CompanionAppDelegate: NSObject, UIApplicationDelegate {
    let container = CompanionContainer()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        CloudPhotoImageDecoder.restrictProcessWideTypes()
        UNUserNotificationCenter.current().delegate = container.receiver
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        container.registration.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        container.registration.didFailToRegister()
    }
}

@main
struct CompanionApp: App {
    @UIApplicationDelegateAdaptor(CompanionAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            CompanionRootView(container: appDelegate.container)
        }
    }
}

struct CompanionRootView: View {
    let container: CompanionContainer

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var navigation = container.navigation
        TabView(selection: $navigation.selectedTab) {
            PairView(model: container.registration)
                .tabItem { Label("TabPair", systemImage: "qrcode") }
                .tag(CompanionTab.pair)
            AlertsView(inbox: container.inbox)
                .tabItem { Label("TabAlerts", systemImage: "bell") }
                .tag(CompanionTab.alerts)
            PhotosView(library: container.photos)
                .tabItem { Label("TabPhotos", systemImage: "photo.on.rectangle") }
                .tag(CompanionTab.photos)
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                await container.becameActive()
            }
        }
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
