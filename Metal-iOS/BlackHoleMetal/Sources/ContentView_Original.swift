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
    @State private var isAutoRotating = false
    @State private var lastResults: GeodesicResults?
    @State private var showingStatistics = false
    @State private var errorMessage: String?
    
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
                                updateCamera()
                            }
                            
                            HStack {
                                VStack {
                                    Text("Azimuth: \(Int(cameraAzimuth))°")
                                    Slider(value: $cameraAzimuth, in: 0...360) { _ in
                                        updateCamera()
                                    }
                                }
                                
                                VStack {
                                    Text("Elevation: \(Int(cameraElevation))°")
                                    Slider(value: $cameraElevation, in: 0...180) { _ in
                                        updateCamera()
                                    }
                                }
                            }
                        }
                    }
                    
                    // Action buttons
                    HStack {
                        Button("Compute Geodesics") {
                            computeGeodesics()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(renderer.isComputing)
                        
                        Button("Reset Camera") {
                            resetCamera()
                        }
                        .buttonStyle(.bordered)
                        
                        Toggle("Auto Rotate", isOn: $isAutoRotating)
                            .toggleStyle(.button)
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
            computeGeodesics()
            startAutoRotation()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateCamera() {
        if !renderer.isComputing {
            computeGeodesics()
        }
    }
    
    private func computeGeodesics() {
        Task {
            do {
                let camera = createCamera()
                let results = try await renderer.computeGeodesics(camera: camera)
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
        updateCamera()
    }
    
    private func startAutoRotation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if isAutoRotating && !renderer.isComputing {
                cameraAzimuth += 1.0
                if cameraAzimuth >= 360.0 {
                    cameraAzimuth = 0.0
                }
                updateCamera()
            }
        }
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

// MARK: - Supporting Views and Types

enum RenderQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case ultra = "Ultra"
    
    var stepCount: Int {
        switch self {
        case .low: return 5000
        case .medium: return 8000
        case .high: return 12000
        case .ultra: return 15000
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .red
        case .medium: return .orange
        case .high: return .green
        case .ultra: return .blue
        }
    }
}

struct QualityIndicatorView: View {
    let quality: RenderQuality
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(quality.color)
                .frame(width: 8, height: 8)
            Text(quality.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ComputingIndicatorView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
            Text("Computing")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(16)
    }
}

struct DistanceIndicatorView: View {
    let distance: Float
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Distance")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(formatDistance(distance))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
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

struct CameraPositionView: View {
    let azimuth: Float
    let elevation: Float
    let isAutoRotating: Bool
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                if isAutoRotating {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.orange)
                        .font(.caption2)
                }
                Text("Camera")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text("\(Int(azimuth))° • \(Int(elevation))°")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
}

struct CameraControlsView: View {
    @Binding var distance: Float
    @Binding var azimuth: Float
    @Binding var elevation: Float
    let minDistance: Float
    let maxDistance: Float
    let onUpdate: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Distance control
            VStack(spacing: 8) {
                HStack {
                    Text("Distance")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(formatDistance(distance))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $distance, in: minDistance...maxDistance) { _ in
                    onUpdate()
                }
                .tint(.blue)
            }
            
            // Orientation controls
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Azimuth")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("\(Int(azimuth))°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $azimuth, in: 0...360) { _ in
                        onUpdate()
                    }
                    .tint(.purple)
                }
                
                VStack(spacing: 8) {
                    Text("Elevation")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("\(Int(elevation))°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $elevation, in: 0...180) { _ in
                        onUpdate()
                    }
                    .tint(.purple)
                }
            }
        }
        .padding(.horizontal, 20)
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

struct SettingsView: View {
    @Binding var quality: RenderQuality
    let renderer: MetalRenderer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Rendering Quality") {
                    Picker("Quality", selection: $quality) {
                        ForEach(RenderQuality.allCases, id: \.self) { quality in
                            HStack {
                                Text(quality.rawValue)
                                Spacer()
                                Text("\(quality.stepCount) steps")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .tag(quality)
                        }
                    }
                    .pickerStyle(.automatic)
                }
                
                Section("Performance") {
                    HStack {
                        Text("GPU Utilization")
                        Spacer()
                        Text("Optimized")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Memory Usage")
                        Spacer()
                        Text("~200 MB")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Hardware") {
                    HStack {
                        Text("Ray Tracing")
                        Spacer()
                        Text("Metal 3.0")
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Optimization")
                        Spacer()
                        Text("Apple Silicon")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sagittarius A* Explorer")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Real-time Black Hole Visualization")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.headline)
                        
                        Text("This application simulates the gravitational effects of Sagittarius A*, the supermassive black hole at the center of our galaxy. Using Einstein's general relativity equations, it traces light rays through curved spacetime to create a photorealistic visualization.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "atom", title: "Photorealistic Rendering", description: "Accurate blackbody radiation and accretion disk physics")
                            FeatureRow(icon: "speedometer", title: "Hardware Accelerated", description: "Optimized for Apple Silicon and Metal 3.0")
                            FeatureRow(icon: "eye", title: "Gravitational Lensing", description: "Real-time spacetime curvature visualization")
                            FeatureRow(icon: "star.circle", title: "Scientific Accuracy", description: "Based on Schwarzschild metric geodesics")
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Controls")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ControlRow(title: "Distance", description: "Adjust camera distance from black hole")
                            ControlRow(title: "Azimuth", description: "Rotate camera horizontally")
                            ControlRow(title: "Elevation", description: "Adjust camera vertical angle")
                            ControlRow(title: "Auto Rotate", description: "Automatic camera rotation")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ControlRow: View {
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("•")
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

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
