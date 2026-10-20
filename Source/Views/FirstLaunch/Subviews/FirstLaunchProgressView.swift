//
//  FirstLaunchProgressView.swift
//
//  Created on 04.07.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// A SwiftUI view that presents an animated progress indicator for the first launch experience.
struct FirstLaunchProgressView: View {
    /// The view model that supplies data and behavior to the view.
    @Environment(FirstLaunchProgressViewModel.self) var viewModel
    
    /// The body property that returns the content of the view.
    var body: some View {
        // A label that displays a system image based on the view model's position.
        Label("", systemImage: viewModel.position.rawValue)
        // Start the animation when the view appears on the screen.
            .onAppear(perform: viewModel.startAnimation)
        // Adjust the font size based on the view model's frame size.
            .font(.system(size: viewModel.frameSize.height * 0.75))
        // Define the frame dimensions based on the view model's frame size.
            .frame(width: viewModel.frameSize.width, height: viewModel.frameSize.height, alignment: .center)
    }
}

#Preview("Progress View") {
    FirstLaunchProgressView()
        .environment(FirstLaunchProgressViewModel.preview)
}
