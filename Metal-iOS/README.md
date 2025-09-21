# Black Hole Metal Implementation for iOS/macOS

This directory contains the Metal GPU accelerated version of the black hole ray tracing simulation optimized for Apple devices.

## Features

- Metal Performance Shaders (MPS) integration for fast geodesic computation
- Native iOS/macOS app with SwiftUI interface
- Real-time ray tracing with Metal compute shaders
- Optimized for Apple Silicon GPUs

## Build Requirements

- Xcode 15.0 or later
- iOS 16.0+ / macOS 13.0+
- Apple Silicon Mac recommended for best performance

## Build Instructions

1. Open `BlackHoleMetal.xcodeproj` in Xcode
2. Select your target device (iOS Simulator, iOS Device, or Mac)
3. Build and run (⌘+R)

## Project Structure

```
Metal-iOS/
├── BlackHoleMetal.xcodeproj    # Xcode project file
├── BlackHoleMetal/             # Main app source
│   ├── App.swift              # SwiftUI app entry point
│   ├── ContentView.swift      # Main UI
│   ├── MetalRenderer.swift    # Metal rendering pipeline
│   └── Shaders/               # Metal shading language files
│       ├── GeodesicCompute.metal  # Geodesic computation
│       └── Raytracing.metal       # Ray tracing pipeline
├── Shared/                    # Shared Swift/Metal code
│   ├── Ray.swift             # Ray structure definitions
│   └── GeodesicMath.swift    # Geodesic mathematics
└── README.md                 # This file
```

## Implementation Details

The Metal implementation ports the core geodesic computation from the OpenGL compute shader to Metal Shading Language (MSL). Key components:

- **Ray Structure**: Contains r, phi, dr, dphi and computed d2r, d2phi values
- **Geodesic RHS**: Right-hand side of geodesic differential equations
- **RK4 Integration**: 4th order Runge-Kutta numerical integration
- **Metal Buffers**: Efficient GPU memory management for ray data

## Performance

The Metal implementation leverages Apple's GPU architecture for significant performance improvements over CPU-based computation while maintaining numerical accuracy.