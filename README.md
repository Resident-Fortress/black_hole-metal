# **black**_**hole**

Black hole simulation project with multiple implementations for different platforms.

## Implementation Variants

This repository contains several implementations of black hole ray tracing and geodesic computation:

### 1. **CPU Implementation** (`CPU-geodesic.cpp`)
- Full 3D geodesic ray tracing on CPU
- OpenGL rendering with traditional graphics pipeline
- High accuracy, suitable for reference computations

### 2. **2D Lensing** (`2D_lensing.cpp`) 
- Simplified 2D gravitational lensing simulation
- Faster computation for educational purposes
- Visual ray trail tracking

### 3. **GPU OpenGL Compute** (`black_hole.cpp` + `geodesic.comp`)
- OpenGL compute shader implementation
- Real-time performance on compatible GPUs
- Cross-platform OpenGL support

### 4. **🚀 Metal GPU (NEW)** (`Metal-iOS/`)
- **Apple Silicon optimized** Metal implementation
- **Native iOS/macOS application** with SwiftUI interface
- **Maximum performance** on Apple devices
- **Complete Xcode project** ready to build

## Project Features

1. **Ray-tracing**: Gravitational lensing simulation using null geodesics
2. **Accretion disk**: Visual effects with realistic physics
3. **Spacetime curvature**: Demonstrates black hole geometry
4. **Real-time performance**: GPU acceleration for interactive experience

## Video Explanation

Thank you everyone for checking out the video, it explains the code in detail: https://www.youtube.com/watch?v=8-B6ryuBkCM

## 🍎 Apple Metal Implementation

The new **Metal-iOS** folder contains a complete native Apple application:
- **Metal compute shaders** for maximum GPU performance
- **SwiftUI interface** with real-time controls
- **Universal app** supporting iPhone, iPad, and Mac
- **Optimized for Apple Silicon** (M1/M2/M3)

### Quick Start (Metal)
```bash
cd Metal-iOS
open BlackHoleMetal.xcodeproj
# Build & Run in Xcode (⌘+R)
```

See [`Metal-iOS/BUILD_INSTRUCTIONS.md`](Metal-iOS/BUILD_INSTRUCTIONS.md) for detailed setup.

## **Building Requirements:**

1. C++ Compiler supporting C++ 17 or newer

2. [Cmake](https://cmake.org/)

3. [Vcpkg](https://vcpkg.io/en/)

4. [Git](https://git-scm.com/)

## **Build Instructions:**

1. Clone the repository:
	-  `git clone https://github.com/kavan010/black_hole.git`
2. CD into the newly cloned directory
	- `cd ./black_hole` 
3. Install dependencies with Vcpkg
	- `vcpkg install`
4. Get the vcpkg cmake toolchain file path
	- `vcpkg integrate install`
	- This will output something like : `CMake projects should use: "-DCMAKE_TOOLCHAIN_FILE=/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake"`
5. Create a build directory
	- `mkdir build`
6. Configure project with CMake
	-  `cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake`
	- Use the vcpkg cmake toolchain path from above
7. Build the project
	- `cmake --build build`
8. Run the program
	- The executables will be located in the build folder

### Alternative: Debian/Ubuntu apt workaround

If you don't want to use vcpkg, or you just need a quick way to install the native development packages on Debian/Ubuntu, install these packages and then run the normal CMake steps above:

```bash
sudo apt update
sudo apt install build-essential cmake \
	libglew-dev libglfw3-dev libglm-dev libgl1-mesa-dev
```

This provides the GLEW, GLFW, GLM and OpenGL development files so `find_package(...)` calls in `CMakeLists.txt` can locate the libraries. After installing, run the `cmake -B build -S .` and `cmake --build build` commands as shown in the Build Instructions.

## **How the code works:**
for 2D: simple, just run 2D_lensing.cpp with the nessesary dependencies installed.

for 3D: black_hole.cpp and geodesic.comp work together to run the simuation faster using GPU, essentially it sends over a UBO and geodesic.comp runs heavy calculations using that data.

should work with nessesary dependencies installed, however I have only run it on windows with my GPU so am not sure!

LMK if you would like an in-depth explanation of how the code works aswell :)
