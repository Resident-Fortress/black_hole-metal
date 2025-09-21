//
//  ContentView.swift
//  BlackHoleMetal
//
//  Main UI for the Black Hole Metal simulation
//

import SwiftUI
import simd

struct ContentView: View {
    @StateObject private var renderer = makeRenderer()
    @State private var cameraDistance: Float = 6.34194e10
    @State private var cameraAzimuth: Float = 0.0
    @State private var cameraElevation: Float = 90.0
    @State private var lastResults: GeodesicResults?
    @State private var showingStatistics = false
    @State private var errorMessage: String?
    @State private var isRenderingHighQuality = false
    
    private let minDistance: Float = 1e10
    private let maxDistance: Float = 1e12
    
    var body: some View {
        NavigationView {
            VStack {
                // Main visualization area
                VStack {
                    RayVisualizationView(rays: renderer.rays, colors: renderer.colors)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .cornerRadius(10)
                    
                    if renderer.isComputing {
                        ProgressView("Computing geodesics...")
                            .padding()
                    }
                }
                
                Spacer()
                
                // Controls
                VStack(spacing: 16) {
                    // Camera controls
                    GroupBox("Camera Controls") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Distance:")
                                Spacer()
                                Text("\(formatDistance(cameraDistance))")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $cameraDistance, 
                                   in: minDistance...maxDistance) { _ in
                                // No automatic rendering - user must press render button
                            }
                            
                            HStack {
                                VStack {
                                    Text("Azimuth: \(Int(cameraAzimuth))°")
                                    Slider(value: $cameraAzimuth, in: 0...360) { _ in
                                        // No automatic rendering - user must press render button
                                    }
                                }
                                
                                VStack {
                                    Text("Elevation: \(Int(cameraElevation))°")
                                    Slider(value: $cameraElevation, in: 0...180) { _ in
                                        // No automatic rendering - user must press render button
                                    }
                                }
                            }
                        }
                    }
                    
                    // Action buttons - focused on still shot rendering
                    VStack(spacing: 12) {
                        Button(isRenderingHighQuality ? "Rendering..." : "Render High Quality Still") {
                            renderHighQualityStill()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(renderer.isComputing || isRenderingHighQuality)
                        
                        HStack {
                            Button("Quick Preview") {
                                renderQuickPreview()
                            }
                            .buttonStyle(.bordered)
                            .disabled(renderer.isComputing)
                            
                            Button("Reset Camera") {
                                resetCamera()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Black Hole Metal")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Statistics") {
                        showingStatistics = true
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showingStatistics) {
            StatisticsView(renderer: renderer, results: lastResults)
        }
        .onAppear {
            // Initial preview rendering only - no auto-rotation
            renderQuickPreview()
        }
    }
    
    // MARK: - Private Methods
    
    private func renderHighQualityStill() {
        Task {
            await MainActor.run {
                isRenderingHighQuality = true
            }
            
            do {
                let camera = createCamera()
                let results = try await renderer.computeGeodesics(camera: camera, highQuality: true)
                await MainActor.run {
                    lastResults = results
                    isRenderingHighQuality = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRenderingHighQuality = false
                }
            }
        }
    }
    
    private func renderQuickPreview() {
        Task {
            do {
                let camera = createCamera()
                let results = try await renderer.computeGeodesics(camera: camera, highQuality: false)
                await MainActor.run {
                    lastResults = results
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func updateCamera() {
        // Removed automatic rendering - now done via explicit buttons only
    }

    private func computeGeodesics() {
        // Deprecated - replaced with explicit render methods
        renderQuickPreview()
    }
    
    private func createCamera() -> CameraUniforms {
        let azimuthRad = cameraAzimuth * .pi / 180.0
        let elevationRad = cameraElevation * .pi / 180.0
        
        let x = cameraDistance * sin(elevationRad) * cos(azimuthRad)
        let y = cameraDistance * cos(elevationRad)
        let z = cameraDistance * sin(elevationRad) * sin(azimuthRad)
        
        let position = simd_float3(x, y, z)
        let target = simd_float3(0, 0, 0)
        let fovY: Float = 60.0 * .pi / 180.0
        let aspect: Float = 4.0 / 3.0  // 800/600
        
        return CameraUniforms(position: position,
                             target: target,
                             fovY: fovY,
                             aspect: aspect,
                             width: 800,
                             height: 600)
    }
    
    private func resetCamera() {
        cameraDistance = 6.34194e10
        cameraAzimuth = 0.0
        cameraElevation = 90.0
        // No automatic rendering - user needs to press render button
    }
    
    private func formatDistance(_ distance: Float) -> String {
        if distance >= 1e12 {
            return String(format: "%.1f T km", distance / 1e15)
        } else if distance >= 1e9 {
            return String(format: "%.1f G km", distance / 1e12)
        } else {
            return String(format: "%.1f M km", distance / 1e9)
        }
    }
}

// MARK: - Ray Visualization View

struct RayVisualizationView: View {
    let rays: [Ray]
    let colors: [simd_float4]
    
    var body: some View {
        Canvas { context, size in
            guard !rays.isEmpty else { return }
            
            let width = Int(size.width)
            let height = Int(size.height)
            let imageWidth = 800
            let imageHeight = 600
            
            for y in 0..<height {
                for x in 0..<width {
                    let rayX = Int(Float(x) / Float(width) * Float(imageWidth))
                    let rayY = Int(Float(y) / Float(height) * Float(imageHeight))
                    let index = rayY * imageWidth + rayX
                    
                    if index < colors.count {
                        let color = colors[index]
                        let swiftUIColor = Color(red: Double(color.x),
                                               green: Double(color.y),
                                               blue: Double(color.z),
                                               opacity: Double(color.w))
                        
                        context.fill(
                            Path(CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(swiftUIColor)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Statistics View

struct StatisticsView: View {
    let renderer: MetalRenderer
    let results: GeodesicResults?
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("Computation Statistics")
                        .font(.headline)
                    
                    Text(renderer.statistics)
                        .font(.system(.body, design: .monospaced))
                    
                    if let results = results {
                        Divider()
                        
                        Text("Analysis")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Black hole hits: \(results.blackHoleHits)")
                            Text("Average escape distance: \(formatDistance(results.averageEscapeDistance))")
                            Text("Computation time: \(String(format: "%.3f", results.computationTime))s")
                        }
                        .font(.system(.body, design: .monospaced))
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Statistics")
            // Apply compact title style only on mobile platforms
            #if os(iOS) || os(tvOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                // Use platform-appropriate toolbar placement
                #if os(iOS) || os(tvOS) || os(visionOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss handled by parent
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        // Dismiss handled by parent
                    }
                }
                #endif
            }
        }
    }
    
    private func formatDistance(_ distance: Float) -> String {
        if distance >= 1e12 {
            return String(format: "%.2e km", distance / 1000)
        } else {
            return String(format: "%.2e km", distance / 1000)
        }
    }
}

// MARK: - Renderer Factory

private func makeRenderer() -> MetalRenderer {
    do {
        return try MetalRenderer(width: 800, height: 600)
    } catch {
        fatalError("Failed to create Metal renderer: \(error)")
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
