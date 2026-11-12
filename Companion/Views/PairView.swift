//
//  PairView.swift
//
//  Created on 10.11.2026.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI
import UIKit

struct PairView: View {
    let model: PushRegistrationModel

    var body: some View {
        VStack(spacing: 20) {
            Text("PairTitle")
                .font(.title.bold())
            content
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .needsAuthorization, .registering:
            ProgressView("PairRegistering")
        case .denied:
            Text("PairDenied")
                .multilineTextAlignment(.center)
            Button("PairOpenSettings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        case .failed:
            Text("PairFailed")
                .multilineTextAlignment(.center)
            Button("PairRetry") {
                Task { await model.start() }
            }
            .buttonStyle(.borderedProminent)
        case .ready(let payload):
            if let image = QRCodeRenderer.image(for: payload.qrString) {
                Image(image, scale: 1, label: Text("PairCodeAccessibility"))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
            }
            Text("PairInstructions")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
    #Preview("Paired") {
        PairView(model: PreviewModels.registration(paired: true))
    }

    #Preview("Unpaired") {
        let model = PreviewModels.registration(paired: false)
        PairView(model: model)
            .task { await model.start() }
    }
#endif

// MARK: - Test Info

// @test-file: CompanionTests/CompanionCoreTests.swift
