//
//  ContentView.swift
//  BlackHoleMetal
//
//  Enhanced UI for the Black Hole Metal simulation with Apple HIG compliance
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
    @State private var selectedQuality: RenderQuality = .high
    @State private var showingInfo = false
    @State private var showingSettings = false
    @State private var isRenderingHighQuality = false
    
    private let minDistance: Float = 1e10
    private let maxDistance: Float = 1e12
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Enhanced Header
                    headerView
                    
                    // Main visualization area with enhanced design
                    visualizationView(geometry: geometry)
                    
                    // Enhanced Controls Panel
                    controlsPanel
                }
            }
        }
        .preferredColorScheme(.dark)
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
        .sheet(isPresented: $showingSettings) {
            SettingsView(quality: $selectedQuality, renderer: renderer)
        }
        .sheet(isPresented: $showingInfo) {
            InfoView()
        }
        .onAppear {
            computeGeodesics()
            startAutoRotation()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sagittarius A* Explorer")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Real-time Black Hole Visualization")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // Quality indicator
                QualityIndicatorView(quality: selectedQuality)
                
                // Action buttons
                Button(action: { showingInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Button(action: { showingStatistics = true }) {
                    Image(systemName: "chart.bar")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.8)
        )
    }
    
    // MARK: - Visualization View
    private func visualizationView(geometry: GeometryProxy) -> some View {
        ZStack {
            // Main rendering area
            RayVisualizationView(rays: renderer.rays, colors: renderer.colors)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
            
            // Overlay information
            VStack {
                HStack {
                    if renderer.isComputing {
                        ComputingIndicatorView()
                    }
                    Spacer()
                    
                    // Distance indicator
                    DistanceIndicatorView(distance: cameraDistance)
                }
                .padding()
                
                Spacer()
                
                // Camera position indicator
                HStack {
                    Spacer()
                    CameraPositionView(
                        azimuth: cameraAzimuth,
                        elevation: cameraElevation,
                        isAutoRotating: isAutoRotating
                    )
                }
                .padding()
            }
        }
        .padding(.horizontal, 20)
        .frame(height: geometry.size.height * 0.6)
    }
    
    // MARK: - Controls Panel
    private var controlsPanel: some View {
        VStack(spacing: 20) {
            // Primary controls
            CameraControlsView(
                distance: $cameraDistance,
                azimuth: $cameraAzimuth,
                elevation: $cameraElevation,
                minDistance: minDistance,
                maxDistance: maxDistance,
                onUpdate: updateCamera
            )
            
            // Action buttons
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    // Primary action
                    Button(action: computeGeodesics) {
                        HStack {
                            if renderer.isComputing && !isRenderingHighQuality {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                            }
                            Text(renderer.isComputing && !isRenderingHighQuality ? "Computing..." : "Render")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        .disabled(renderer.isComputing)
                    }
                    
                    // Secondary actions
                    Button(action: resetCamera) {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(25)
                    }
                    
                    Button(action: { isAutoRotating.toggle() }) {
                        Image(systemName: isAutoRotating ? "pause.circle" : "play.circle")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(isAutoRotating ? Color.orange.opacity(0.8) : Color.secondary.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(25)
                    }
                }
                
                // High Quality Still Rendering Button
                Button(action: renderHighQualityStill) {
                    HStack {
                        if isRenderingHighQuality {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "camera.circle.fill")
                                .font(.title3)
                        }
                        Text(isRenderingHighQuality ? "Rendering High Quality..." : "Render High Quality Still")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.teal]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(22)
                    .disabled(renderer.isComputing || isRenderingHighQuality)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.9)
        )
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
                        Text("Rays Statistics")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Total rays: \(results.rays.count)")
                            Text("Black hole hits: \(results.blackHoleHits)")
                            Text("Computation time: \(String(format: "%.2f", results.computationTime))s")
                            Text("Average escape distance: \(formatDistance(results.averageEscapeDistance))")
                        }
                        .font(.system(.body, design: .monospaced))
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss handled by parent
                    }
                }
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
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