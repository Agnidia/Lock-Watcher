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
    var photoPath = NavigationPath()
    #if DEBUG
        var scrollsDetailToEnd = false
    #endif
}

/// What a preview or screenshot launch swaps in for the live services. Only DEBUG builds can create one.
struct LaunchOverrides {
    var alerts: [ReceivedAlert]
    var photoSource: any CloudPhotoSource
    var isPro: Bool
    var plans: [ProPlan]
    var deviceToken: Data?
    var isAuthorized: Bool
    var tab: CompanionTab
    var openAlert: ReceivedAlert?
    var openPhoto: CloudPhoto?
    var scrollsDetailToEnd = false

    #if !DEBUG
        static func current() -> LaunchOverrides? {
            nil
        }
    #endif
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
    private let launch: LaunchOverrides?

    convenience init() {
        self.init(launch: LaunchOverrides.current())
    }

    #if DEBUG
        /// Lets a `#Preview` build the real root view from fixture data instead of the process environment.
        convenience init(overrides: LaunchOverrides) {
            self.init(launch: overrides)
        }
    #endif

    private init(launch: LaunchOverrides?) {
        let inbox = AlertInbox(store: launch.map { InMemoryAlertStore(alerts: $0.alerts) as any AlertPersisting } ?? FileAlertStore.applicationSupport())
        let registrar: any RemoteNotificationRegistering = launch.map { StubRemoteNotificationRegistrar(isAuthorized: $0.isAuthorized) }
            ?? LiveRemoteNotificationRegistrar()
        let navigation = CompanionNavigation()
        self.navigation = navigation
        self.launch = launch
        self.inbox = inbox
        photos = CloudPhotoLibrary(source: launch?.photoSource ?? ICloudPhotoSource())
        pro = ProStore(fixtureIsPro: launch?.isPro ?? (Self.isProForced ? true : nil), fixturePlans: launch?.plans ?? [])
        registration = PushRegistrationModel(registrar: registrar, configuration: .main())
        receiver = NotificationReceiver { [weak inbox] alerts, opened in
            inbox?.ingest(alerts)
            if opened {
                navigation.selectedTab = .alerts
            }
        }
        if let launch {
            navigation.selectedTab = launch.tab
            if let alert = launch.openAlert {
                navigation.alertPath.append(alert)
            }
            if let photo = launch.openPhoto {
                navigation.photoPath.append(photo)
            }
            #if DEBUG
                navigation.scrollsDetailToEnd = launch.scrollsDetailToEnd
            #endif
        }
    }

    /// Re-registers on every activation because APNs may rotate the token, and pulls alerts delivered while the app was closed.
    /// The photo refresh runs beside the registration because the notification prompt can hold `start()` open indefinitely.
    func becameActive() async {
        async let photosRefreshed: Void = photos.refresh()
        async let proRefreshed: Void = pro.refresh()
        await registration.start()
        if let token = launch?.deviceToken {
            registration.didRegister(deviceToken: token)
        }
        if launch == nil {
            await inbox.ingest(receiver.deliveredAlerts())
        }
        await photosRefreshed
        await proRefreshed
    }

    /// DEBUG only: `LW_COMPANION_FORCE_PRO=1` unlocks Pro with the real alerts and photos, skipping StoreKit. Without it a build shows the real entitlement.
    private static var isProForced: Bool {
        #if DEBUG
            ProcessInfo.processInfo.environment[LaunchVariable.forcePro.rawValue] == "1"
        #else
            false
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
            PhotosView(library: container.photos, isPro: container.pro.isPro, showPro: { container.navigation.selectedTab = .pro },
                       path: $navigation.photoPath)
                .tabItem { Label("TabPhotos", systemImage: "photo.on.rectangle") }
                .tag(CompanionTab.photos)
            PairView(model: container.registration)
                .tabItem { Label("TabPair", systemImage: "qrcode") }
                .tag(CompanionTab.pair)
            ProView(store: container.pro)
                .tabItem { Label { Text("TabPro") } icon: { proTabIcon } }
                .tag(CompanionTab.pro)
        }
        .task(id: scenePhase) { @MainActor in
            if scenePhase == .active {
                await container.becameActive()
            }
        }
        #if DEBUG
        .environment(\.scrollsDetailToEnd, container.navigation.scrollsDetailToEnd)
        #endif
    }

    /// A tab bar renders icons as templates and ignores `foregroundStyle`; an always-original image keeps its colour, so only this tab takes the app icon's blue.
    private var proTabIcon: Image {
        guard container.pro.isPro,
              let tinted = UIImage(systemName: "star.fill")?.withTintColor(ProTint.uiColor, renderingMode: .alwaysOriginal)
        else { return Image(systemName: "star") }
        return Image(uiImage: tinted)
    }
}

#if DEBUG
    #Preview("Pro, every trigger") {
        CompanionRootView(container: CompanionContainer(overrides: CompanionFixture.proTriggers.overrides))
    }
#endif

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
