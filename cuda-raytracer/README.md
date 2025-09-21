# CUDA Black Hole Ray Tracer

A photorealistic, GPU-accelerated black hole simulation using CUDA ray tracing.

## Features

- **Full GPU Acceleration**: All ray tracing computations performed on NVIDIA GPU
- **Photorealistic Rendering**: 
  - Accurate geodesic ray tracing through curved spacetime
  - Realistic accretion disk with temperature-based blackbody radiation
  - Gravitational redshift and Doppler shift effects  
  - Visible light beam interactions with spacetime curvature
- **Real-time Performance**: Optimized for NVIDIA RTX 4060 8GB and similar cards
- **Interactive Controls**: Full camera control with mouse and keyboard

## System Requirements

### Hardware
- **NVIDIA GPU**: RTX 4060 8GB or similar (Compute Capability 8.9)
- **CPU**: Modern multi-core processor
- **RAM**: 8GB minimum, 16GB recommended
- **OS**: Ubuntu 22.04 LTS (tested), other Linux distributions should work

### Software
- **CUDA Toolkit**: 12.0 or later
- **OpenGL**: 3.3 or later
- **CMake**: 3.18 or later
- **GCC**: 9.0 or later with C++17 support

## Dependencies

- CUDA Toolkit (cudart, cuda_driver)
- OpenGL (libgl1-mesa-dev)
- GLEW (libglew-dev)
- GLFW3 (libglfw3-dev)
- GLM (libglm-dev)

## Building

### Ubuntu/Debian
```bash
# Install dependencies
sudo apt update
sudo apt install build-essential cmake libglew-dev libglfw3-dev libglm-dev libgl1-mesa-dev

# Install CUDA Toolkit (if not already installed)
# Follow NVIDIA's official installation guide for your system

# Build
mkdir build && cd build
cmake ..
make -j$(nproc)
```

## Running

```bash
./BlackHoleCUDA
```

## Controls

- **Mouse Drag**: Rotate camera around black hole
- **Mouse Wheel**: Zoom in/out  
- **R**: Reset camera to default position
- **P**: Cycle through camera presets (equatorial, polar, close-up)
- **ESC**: Exit application

## Technical Details

### Ray Tracing Algorithm
- Uses 4th-order Runge-Kutta integration for geodesic equations
- Handles null geodesics in Schwarzschild spacetime
- Accurate light ray deflection and gravitational lensing

### Accretion Disk Physics
- Temperature profile: T ∝ r^(-0.75) (standard thin disk model)
- Blackbody radiation spectrum calculation
- Doppler shift from disk rotation
- Gravitational redshift effects

### Performance Optimizations
- CUDA thread block optimization for GPU architecture
- Adaptive ray step count based on camera movement
- Fast math operations where physically reasonable
- Memory coalescing for optimal GPU memory access

### Visual Enhancements
- Hawking radiation glow near event horizon
- Visible light beams showing spacetime curvature
- Animated effects with time-based parameters
- Cosmic background with procedural star field

## Physics Accuracy

This simulation implements:
- ✅ Schwarzschild metric for black hole spacetime
- ✅ Null geodesic ray tracing
- ✅ Gravitational time dilation
- ✅ Gravitational redshift
- ✅ Gravitational lensing
- ✅ Accretion disk physics (simplified)
- ✅ Doppler shift effects

## Performance

Typical performance on RTX 4060 8GB:
- 1200x900 resolution: 60+ FPS
- 1920x1080 resolution: 45+ FPS  
- 2560x1440 resolution: 30+ FPS

Performance scales with resolution and ray complexity.

## Future Enhancements

- Kerr metric for rotating black holes
- More complex accretion disk models
- Particle system for jets and outflows
- VR support
- Multi-GPU scaling