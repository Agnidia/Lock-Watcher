//
//  CompanionApp.swift
//
//  Created on 11.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import UIKit
import UserNotifications

enum CompanionTab: Hashable {
    case alerts
    case photos
    case pair
    case pro
}

@MainActor
@Observable
final class CompanionNavigation {
    var selectedTab: CompanionTab = .alerts
    /// Alert details pushed on the Alerts tab; a screenshot fixture fills it to open a detail at launch.
    var alertPath = NavigationPath()
}

/// DEBUG screenshot states, picked by the `LW_COMPANION_FIXTURE` launch variable.
enum CompanionFixture: String {
    case ready
    case denied
    case alerts
    /// Fifteen alerts on a free account: the list stops at ten and offers the upgrade.
    case alertsMany
    /// The same fifteen alerts with Pro active.
    case pro
    /// A free account on the Pro tab with three made-up plans, because the App Store is not reachable in screenshots.
    case proOffers
    /// Pro with the newest alert open and every detail field filled, photo included.
    case proDetail
    /// Pro with the newest alert open and only the always-present fields, as a Mac with location, IP and trace turned off sends.
    case proDetailBare
    case photos
    case photosUnavailable

    var deviceToken: Data? {
        self == .denied ? nil : Data((0 ..< 32).map { UInt8($0 * 7 & 0xFF) })
    }

    var alerts: [ReceivedAlert] {
        switch self {
        case .alerts:
            [
                ReceivedAlert(id: "fixture-2", title: "Lock-Watcher", body: "USB device connected · 14:32", trigger: "usbConnected",
                              date: Date(timeIntervalSince1970: 1_793_021_520), latitude: 50.4501, longitude: 30.5234, ip: "203.0.113.7"),
                ReceivedAlert(id: "fixture-1", title: "Lock-Watcher", body: "Mac woke up · 09:05", trigger: "onWakeUp",
                              date: Date(timeIntervalSince1970: 1_793_001_900), latitude: nil, longitude: nil, ip: nil)
            ]
        case .alertsMany, .pro:
            (0 ..< 15).map { index in
                ReceivedAlert(id: "fixture-\(index)", title: "Lock-Watcher", body: "Mac woke up · alert \(index + 1)", trigger: "onWakeUp",
                              date: Date(timeIntervalSince1970: 1_793_021_520 - Double(index) * 3600), latitude: nil, longitude: nil, ip: nil)
            }
        case .proDetail:
            [
                ReceivedAlert(id: "fixture-detail", title: "Lock-Watcher", body: "USB device connected · 14:32", trigger: "usbConnected",
                              date: Date(timeIntervalSince1970: 1_793_021_520), latitude: 50.4501, longitude: 30.5234, ip: "203.0.113.7",
                              traceRoute: (1 ... 9).map { "\($0)  10.0.\($0).1  \($0 * 3) ms" }.joined(separator: "\n"),
                              fileName: "front-door.jpeg", mediaKind: PushAlertPayload.photoMedia, host: "MacBook Pro", timeZoneID: "Pacific/Honolulu"),
                ReceivedAlert(id: "fixture-older", title: "Lock-Watcher", body: "Mac woke up · 09:05", trigger: "onWakeUp",
                              date: Date(timeIntervalSince1970: 1_793_001_900), latitude: nil, longitude: nil, ip: nil)
            ]
        case .proDetailBare:
            [
                ReceivedAlert(id: "fixture-bare", title: "Lock-Watcher", body: "Mac woke up · 09:05", trigger: "onWakeUp",
                              date: Date(timeIntervalSince1970: 1_793_001_900), latitude: nil, longitude: nil, ip: nil, host: "MacBook Pro")
            ]
        case .ready, .denied, .photos, .photosUnavailable, .proOffers:
            []
        }
    }

    var isPro: Bool {
        self == .pro || self == .proDetail || self == .proDetailBare
    }

    var plans: [ProPlan] {
        guard self == .proOffers else { return [] }
        return [
            ProPlan(id: ProProduct.year, kind: .year, title: "Pro Yearly", price: "$7.99", monthlyEquivalent: "$0.67", savingsPercent: 33),
            ProPlan(id: ProProduct.month, kind: .month, title: "Pro Monthly", price: "$0.99", monthlyEquivalent: nil, savingsPercent: nil),
            ProPlan(id: ProProduct.lifetime, kind: .lifetime, title: "Pro Lifetime", price: "$20.99", monthlyEquivalent: nil, savingsPercent: nil)
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
    let pro: ProStore
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
        pro = ProStore(fixtureIsPro: fixture?.isPro ?? (Self.isProForced ? true : nil), fixturePlans: fixture?.plans ?? [])
        registration = PushRegistrationModel(registrar: registrar, configuration: .main())
        receiver = NotificationReceiver { [weak inbox] alerts, opened in
            inbox?.ingest(alerts)
            if opened {
                navigation.selectedTab = .alerts
            }
        }
        switch fixture {
        case .alerts, .alertsMany, .pro: navigation.selectedTab = .alerts
        case .proDetail, .proDetailBare:
            navigation.selectedTab = .alerts
            if let first = fixture?.alerts.first {
                navigation.alertPath.append(first)
            }
        case .photos, .photosUnavailable: navigation.selectedTab = .photos
        case .proOffers: navigation.selectedTab = .pro
        case .ready, .denied, .none: break
        }
    }

    /// Re-registers on every activation because APNs may rotate the token, and pulls alerts delivered while the app was closed.
    /// The photo refresh runs beside the registration because the notification prompt can hold `start()` open indefinitely.
    func becameActive() async {
        async let photosRefreshed: Void = photos.refresh()
        async let proRefreshed: Void = pro.refresh()
        await registration.start()
        if let token = fixture?.deviceToken {
            registration.didRegister(deviceToken: token)
        }
        if fixture == nil {
            await inbox.ingest(receiver.deliveredAlerts())
        }
        await photosRefreshed
        await proRefreshed
    }

    private static func photoSource(for fixture: CompanionFixture?) -> any CloudPhotoSource {
        #if DEBUG
            if let fixture {
                return FixturePhotoSource(mode: fixture.photoMode)
            }
        #endif
        return ICloudPhotoSource()
    }

    /// DEBUG only: `LW_COMPANION_FORCE_PRO=1` unlocks Pro with the real alerts and photos, skipping StoreKit. Without it a build shows the real entitlement.
    private static var isProForced: Bool {
        #if DEBUG
            ProcessInfo.processInfo.environment["LW_COMPANION_FORCE_PRO"] == "1"
        #else
            false
        #endif
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
            AlertsView(inbox: container.inbox, photos: container.photos, isPro: container.pro.isPro,
                       showPro: { container.navigation.selectedTab = .pro }, path: $navigation.alertPath)
                .tabItem { Label("TabAlerts", systemImage: "bell") }
                .tag(CompanionTab.alerts)
            PhotosView(library: container.photos, isPro: container.pro.isPro, showPro: { container.navigation.selectedTab = .pro })
                .tabItem { Label("TabPhotos", systemImage: "photo.on.rectangle") }
                .tag(CompanionTab.photos)
            PairView(model: container.registration)
                .tabItem { Label("TabPair", systemImage: "qrcode") }
                .tag(CompanionTab.pair)
            ProView(store: container.pro)
                .tabItem { Label { Text("TabPro") } icon: { proTabIcon } }
                .tag(CompanionTab.pro)
        }
        .task(id: scenePhase) {
            if scenePhase == .active {
                await container.becameActive()
            }
        }
    }

    /// A tab bar renders icons as templates and ignores `foregroundStyle`; an always-original image keeps its colour, so only this tab turns green.
    private var proTabIcon: Image {
        guard container.pro.isPro,
              let green = UIImage(systemName: "star.fill")?.withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
        else { return Image(systemName: "star") }
        return Image(uiImage: green)
    }
}

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
