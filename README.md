# **black**_**hole** - Enhanced Photorealistic GPU Simulation

Enhanced black hole simulation project with multiple GPU-accelerated implementations for different platforms.

## **NEW: Enhanced Photorealistic Features**

### Recent Enhancements
- **Visible Light Beams**: Interactive light rays showing spacetime curvature
- **Realistic Accretion Disk**: Temperature-based blackbody radiation with Doppler shifts
- **Gravitational Redshift**: Accurate color shifting based on gravitational potential
- **Enhanced Performance**: Better GPU utilization and optimization
- **Improved Interactivity**: Enhanced camera controls and visual presets

### **NEW: CUDA Ray-Traced Version**
Complete CUDA implementation in `/cuda-raytracer/` optimized for NVIDIA RTX 4060 8GB:
- Full GPU ray tracing pipeline
- Photorealistic material system  
- Real-time performance optimization
- Advanced geodesic calculations on GPU

## Implementation Variants

This repository contains several implementations of black hole ray tracing and geodesic computation:

### 1. **Enhanced GPU OpenGL Compute** (`black_hole.cpp` + `geodesic.comp`)
- **Photorealistic rendering** with visible light beams
- **Enhanced accretion disk** with temperature gradients and realistic physics
- **Interactive controls** with camera presets (R, P keys)
- **GPU-accelerated** geodesic ray tracing
- **Real-time performance** on compatible GPUs

### 2. ** CUDA Ray-Traced Version** (`cuda-raytracer/`) 
- **NVIDIA RTX 4060 optimized** CUDA implementation
- **Full GPU acceleration** for all calculations
- **Photorealistic materials** and lighting
- **Advanced ray tracing** pipeline
- **Maximum performance** on NVIDIA hardware

### 3. **Enhanced Metal GPU** (`Metal-iOS/`)
- **Apple M4 Silicon optimized** Metal implementation
- **Enhanced photorealistic shaders** with improved lighting
- **Native iOS/macOS application** with SwiftUI interface
- **Maximum performance** on Apple devices
- **Complete Xcode project** ready to build

### 4. **CPU Implementation** (`CPU-geodesic.cpp`)
- Full 3D geodesic ray tracing on CPU
- OpenGL rendering with traditional graphics pipeline
- High accuracy, suitable for reference computations

### 5. **2D Lensing** (`2D_lensing.cpp`) 
- Simplified 2D gravitational lensing simulation
- Faster computation for educational purposes
- Visual ray trail tracking

## Project Features

### Visual Enhancements
1. **Photorealistic Ray-tracing**: Enhanced gravitational lensing with visible light interactions
2. **Advanced Accretion Disk**: Temperature-based spectrum with Doppler shifts and turbulence
3. **Spacetime Visualization**: Visible light beams showing curvature effects
4. **Real-time Performance**: GPU acceleration for interactive experience
5. **Enhanced Lighting**: Hawking radiation glow and gravitational redshift effects

### Interactive Controls
- **Mouse Drag**: Orbit camera around black hole
- **Mouse Wheel**: Zoom in/out
- **R Key**: Reset camera position
- **P Key**: Cycle through visual presets (equatorial, polar, close-up)
- **G Key**: Toggle gravity simulation for objects
- **ESC**: Exit application

### Performance Targets
- **OpenGL Version**: 60+ FPS at 1080p on modern GPUs
- **CUDA Version**: 60+ FPS at 1200x900 on RTX 4060 8GB
- **Metal Version**: 60+ FPS at native resolution on M4 Apple Silicon

## Video Explanation

Original Author - @kavan010, he explains the code in detail and is the original repo owner at https://github.com/kavan010/black_hole 
His video on the OpenGL implementation: https://www.youtube.com/watch?v=8-B6ryuBkCM

## Apple Metal Implementation

The **Metal-iOS** folder contains a complete native Apple application:
- **Enhanced Metal compute shaders** for maximum GPU performance
- **SwiftUI interface** with real-time controls
- **Universal app** supporting iPhone, iPad, and Mac
- **Optimized for Apple Silicon** (M1/M2/M3/M4)

### Quick Start (Metal)
```bash
cd Metal-iOS
open BlackHoleMetal.xcodeproj
# Build & Run in Xcode (⌘+R)
```

See [`Metal-iOS/BUILD_INSTRUCTIONS.md`](Metal-iOS/BUILD_INSTRUCTIONS.md) for detailed setup.

## CUDA Implementation

The **cuda-raytracer** folder contains a complete CUDA ray tracing implementation:
- **Full GPU acceleration** using CUDA kernels
- **Photorealistic materials** and lighting system
- **Optimized for RTX 4060 8GB** and similar cards
- **Real-time interactive performance**

### Quick Start (CUDA)
```bash
cd cuda-raytracer
mkdir build && cd build
cmake .. && make -j$(nproc)
./BlackHoleCUDA
```

See [`cuda-raytracer/README.md`](cuda-raytracer/README.md) for detailed setup and requirements.

## **Building Requirements:**

### For OpenGL Version:
1. C++ Compiler supporting C++ 17 or newer
2. [CMake](https://cmake.org/)
3. [Vcpkg](https://vcpkg.io/en/) (optional)
4. [Git](https://git-scm.com/)

### For CUDA Version:
1. **NVIDIA GPU** with Compute Capability 8.9+ (RTX 4060 or similar)
2. **CUDA Toolkit 12.0+**
3. All OpenGL requirements above

### For Metal Version:
1. **macOS** or **iOS** device
2. **Xcode 15+**
3. **Metal support** (all modern Apple devices)

## **Build Instructions:**

### Enhanced OpenGL Version
1. Clone the repository:
	-  `git clone https://github.com/Resident-Fortress/black_hole-metal.git`
2. CD into the newly cloned directory
	- `cd ./black_hole-metal` 
3. Install dependencies with Vcpkg (optional)
	- `vcpkg install`
4. Get the vcpkg cmake toolchain file path (if using vcpkg)
	- `vcpkg integrate install`
	- This will output something like : `CMake projects should use: "-DCMAKE_TOOLCHAIN_FILE=/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake"`
5. Create a build directory
	- `mkdir build`
6. Configure project with CMake
	-  `cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake`
	- Use the vcpkg cmake toolchain path from above (or omit if not using vcpkg)
7. Build the project
	- `cmake --build build`
8. Run the enhanced program
	- `./build/BlackHole3D`

### Alternative: Debian/Ubuntu apt workaround

If you don't want to use vcpkg, or you just need a quick way to install the native development packages on Debian/Ubuntu, install these packages and then run the normal CMake steps above:

```bash
sudo apt update
sudo apt install build-essential cmake \
	libglew-dev libglfw3-dev libglm-dev libgl1-mesa-dev
```

This provides the GLEW, GLFW, GLM and OpenGL development files so `find_package(...)` calls in `CMakeLists.txt` can locate the libraries. After installing, run the `cmake -B build -S .` and `cmake --build build` commands as shown in the Build Instructions.

### CUDA Version Build
```bash
cd cuda-raytracer
mkdir build && cd build
cmake ..
make -j$(nproc)
./BlackHoleCUDA
```

**Requirements**: NVIDIA GPU with CUDA Toolkit 12.0+ installed.

## **How the Enhanced Code Works:**

### Enhanced OpenGL Implementation
- **`black_hole.cpp`**: Main application with enhanced camera controls and interactivity
- **`geodesic.comp`**: Enhanced compute shader with photorealistic effects:
  - Visible light beam generation and spacetime interaction
  - Temperature-based accretion disk rendering with blackbody spectrum
  - Gravitational redshift and Doppler shift calculations
  - Enhanced event horizon rendering with Hawking radiation glow
  - Time dilation effects visualization

### CUDA Implementation
- **`cuda_kernels.cu`**: GPU ray tracing kernels with:
  - Optimized geodesic integration on GPU
  - Photorealistic material system
  - Advanced lighting calculations
  - Memory-optimized algorithms for RTX 4060
- **`main.cpp`**: CUDA-OpenGL interop with real-time rendering
- **Full GPU pipeline**: All calculations performed on GPU for maximum performance

### Metal Implementation
- **Enhanced Metal shaders** with Apple Silicon optimization
- **SwiftUI interface** for native Apple experience
- **M4 GPU optimizations** for maximum performance

## Performance Comparison

| Implementation | Target Hardware | Resolution | Performance |
|---------------|----------------|------------|-------------|
| **Enhanced OpenGL** | Modern GPUs | 1920x1080 | 60+ FPS |
| **CUDA Ray Tracer** | RTX 4060 8GB | 1200x900 | 60+ FPS |
| **Metal (M4)** | Apple M4 Silicon | Native | 60+ FPS |
| **CPU Reference** | Modern CPU | 800x600 | 5-10 FPS |

## Physics Accuracy

Enhanced implementations include:
- **Schwarzschild metric** for accurate black hole spacetime
- **Null geodesic ray tracing** with 4th-order Runge-Kutta integration
- **Gravitational time dilation** effects
- **Gravitational redshift** color shifting
- **Gravitational lensing** with light ray deflection
- **Accretion disk physics** with temperature profiles
- **Doppler shift effects** from disk rotation
- **Visible light beam interactions** with spacetime curvature

## Target Hardware Optimization

- **RTX 4060 8GB**: CUDA version optimized for Ada Lovelace architecture
- **Apple M4 Silicon**: Metal version optimized for unified memory architecture
- **Modern OpenGL GPUs**: Enhanced compute shaders for broad compatibility

LMK if you would like an in-depth explanation of how the enhanced code works! 🚀
