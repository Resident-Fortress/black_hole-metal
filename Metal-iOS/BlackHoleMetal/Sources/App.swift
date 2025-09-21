//
//  App.swift
//  BlackHoleMetal
//
//  SwiftUI app entry point for the Black Hole Metal simulation
//

import SwiftUI

@main
struct BlackHoleMetalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif
    }
}