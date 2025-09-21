# Build Instructions for Black Hole Metal (iOS/macOS)

This document provides detailed instructions for building and running the Metal GPU accelerated version of the black hole ray tracing simulation on Apple devices.

## Prerequisites

### Required Software
- **Xcode 15.0 or later** - Available from the Mac App Store or Apple Developer
- **macOS 13.0 (Ventura) or later** - Required for Xcode 15
- **Command Line Tools** - Install with `xcode-select --install`

### Recommended Hardware
- **Apple Silicon Mac** (M1/M2/M3) - Best performance with unified memory architecture
- **Intel Mac with dedicated GPU** - Will work but with reduced performance
- **iOS Device with A12 chip or later** - For iOS deployment
- **At least 8GB RAM** - For smooth development experience

### Target Platforms
- **iOS 16.0+** - iPhone and iPad support
- **macOS 13.0+** - Native Mac application
- **macOS via Mac Catalyst** - Optional, automatically supported

## Project Structure

```
Metal-iOS/
├── BlackHoleMetal.xcodeproj          # Main Xcode project
├── BlackHoleMetal/                   # Application source code
│   ├── Sources/                      # Swift source files
│   │   ├── App.swift                # SwiftUI app entry point
│   │   ├── ContentView.swift        # Main user interface
│   │   └── MetalRenderer.swift      # Metal rendering pipeline
│   ├── Shaders/                     # Metal shading language files
│   │   └── GeodesicCompute.metal    # GPU geodesic computation
│   ├── Assets.xcassets              # App icons and resources
│   └── Preview Content/             # SwiftUI preview assets
├── Shared/                          # Shared code between targets
│   └── Ray.swift                    # Ray structure definitions
├── TestGeodesic.swift              # Command-line validation test
└── README.md                       # This file
```

## Build Steps

### Option 1: Build with Xcode (Recommended)

1. **Open the Project**
   ```bash
   cd Metal-iOS
   open BlackHoleMetal.xcodeproj
   ```

2. **Select Target**
   - For iOS: Choose "BlackHoleMetal" target and an iOS Simulator or connected device
   - For macOS: Choose "BlackHoleMetal" target and "My Mac"

3. **Configure Signing** (if running on device)
   - Go to Project Settings → Signing & Capabilities
   - Select your Apple Developer Team
   - Xcode will automatically handle provisioning

4. **Build and Run**
   - Press `⌘+R` or click the Play button
   - First build may take a few minutes to compile Metal shaders

### Option 2: Build with Command Line

1. **Build for iOS**
   ```bash
   cd Metal-iOS
   xcodebuild -project BlackHoleMetal.xcodeproj \
              -scheme BlackHoleMetal \
              -destination 'platform=iOS Simulator,name=iPhone 15' \
              build
   ```

2. **Build for macOS**
   ```bash
   cd Metal-iOS
   xcodebuild -project BlackHoleMetal.xcodeproj \
              -scheme BlackHoleMetal \
              -destination 'platform=macOS' \
              build
   ```

3. **Run Built Application**
   ```bash
   # macOS
   open build/Release/BlackHoleMetal.app
   
   # iOS (requires additional steps for deployment)
   ```

## Validation Testing

Before building the full app, you can validate the geodesic computation:

```bash
cd Metal-iOS
swift TestGeodesic.swift
```

Expected output should show successful validation of:
- Ray initialization from position and direction
- Geodesic equation derivatives (d²r/dλ², d²φ/dλ²)
- Conservation quantities (energy E, angular momentum L)

## Troubleshooting

### Common Build Issues

**Error: "Metal device not found"**
- Ensure you're running on compatible hardware
- Virtual machines typically don't support Metal
- Some older Intel Macs may have limited Metal support

**Error: "No such module 'Metal'"**
- Make sure you're building for iOS 16.0+ or macOS 13.0+
- Check deployment target in project settings

**Error: "Failed to create compute pipeline state"**
- Metal shader compilation failed
- Check `GeodesicCompute.metal` for syntax errors
- Ensure shader function names match Swift code

**Error: "Code signing required"**
- For device deployment, you need an Apple Developer account
- Use iOS Simulator for development without signing

### Performance Issues

**Slow computation on older devices:**
- Reduce image resolution in `MetalRenderer.swift`
- Decrease maximum iteration count in the Metal shader
- Consider adaptive quality based on device capabilities

**High memory usage:**
- Monitor Metal buffer allocation
- Reduce ray count for lower-end devices
- Implement memory pool for buffer reuse

### Device-Specific Considerations

**iOS Devices:**
- Thermal throttling may affect performance during extended use
- Battery usage will be higher due to GPU computation
- Consider power management for background processing

**macOS Intel Macs:**
- Performance will be lower than Apple Silicon
- Some older GPUs may have compute limitations
- External GPU (eGPU) support varies by model

## Performance Optimization

### Metal Shader Optimization
- Use appropriate data types (`float` vs `half`)
- Minimize branching in GPU kernels
- Optimize memory access patterns
- Use shared memory for frequently accessed data

### Swift Code Optimization
- Minimize CPU-GPU synchronization
- Use asynchronous command buffer execution
- Implement proper memory management for Metal buffers
- Cache computed resources when possible

## Deployment

### iOS App Store
1. Archive the project in Xcode
2. Upload to App Store Connect
3. Configure app metadata and screenshots
4. Submit for review

### macOS Distribution
1. Archive for macOS in Xcode
2. Export as Developer ID Application
3. Notarize the application with Apple
4. Distribute via Mac App Store or direct download

## Advanced Configuration

### Customizing Geodesic Parameters
Edit `GeodesicCompute.metal` to modify:
- Black hole mass and Schwarzschild radius
- Integration step size (`D_LAMBDA`)
- Maximum iteration count
- Escape radius threshold

### Adding Visual Features
- Accretion disk rendering
- Multiple black holes
- Gravitational lensing effects
- Real-time parameter adjustment

## Support and Debugging

### Debug Output
Enable Metal debugging in Xcode:
1. Edit Scheme → Run → Diagnostics
2. Check "Metal API Validation"
3. Enable GPU Frame Capture

### Performance Profiling
Use Xcode Instruments:
1. Profile → Metal System Trace
2. Monitor GPU utilization and memory
3. Identify performance bottlenecks

### Logging
The app includes comprehensive logging for:
- Metal device initialization
- Shader compilation status
- Computation timing
- Memory allocation

For additional help, check the main project README or create an issue in the repository.