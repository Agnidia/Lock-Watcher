//
//  PreviewContainer.swift
//
//  Created on 12.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

#if DEBUG
import Foundation

/// Builds each model a `#Preview` needs by hand, because `CompanionContainer` reads the process environment and has no injectable parts.
@MainActor
enum PreviewModels {
    static func inbox(_ alerts: [ReceivedAlert]) -> AlertInbox {
        AlertInbox(store: InMemoryAlertStore(alerts: alerts))
    }
    
    /// Starts in `.loading`; the preview calls `refresh()` in a `.task` to reach the requested state.
    static func photos(mode: FixturePhotoSource.Mode = .photos, count: Int = PreviewPersons.count) -> CloudPhotoLibrary {
        CloudPhotoLibrary(source: FixturePhotoSource(mode: mode, count: count))
    }
    
    static func pro(active: Bool) -> ProStore {
        ProStore(fixtureIsPro: active, fixturePlans: active ? [] : CompanionFixture.proOffers.overrides.plans)
    }
    
    /// Unpaired is the denied state, which only appears after `start()`; the preview calls it in a `.task`.
    static func registration(paired: Bool) -> PushRegistrationModel {
        let model = PushRegistrationModel(registrar: StubRemoteNotificationRegistrar(isAuthorized: paired),
                                          configuration: CompanionConfiguration(topic: "com.igrsoft.Lock-Watcher", environment: .sandbox))
        if paired {
            model.didRegister(deviceToken: Data((0 ..< 32).map { UInt8($0 * 7 & 0xFF) }))
        }
        return model
    }
    
    static func alert(_ trigger: AlertTrigger) -> ReceivedAlert {
        PreviewAlerts.alert(for: trigger) ?? PreviewAlerts.bare()
    }
}
#endif
