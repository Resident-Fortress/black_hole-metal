#!/bin/bash

# Quick build script for black hole simulation
# Builds both OpenGL and CUDA versions (if available)

set -e

echo "=== Black Hole Simulation - Quick Build ==="
echo

# Build OpenGL version
echo "Building OpenGL version..."
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
echo "✅ OpenGL version built successfully!"
echo

# Try to build CUDA version
cd ..
if [ -d "cuda-raytracer" ]; then
    echo "Building CUDA version..."
    cd cuda-raytracer
    mkdir -p build
    cd build
    
    if cmake -DCMAKE_BUILD_TYPE=Release .. 2>/dev/null; then
        if make -j$(nproc) 2>/dev/null; then
            echo "✅ CUDA version built successfully!"
        else
            echo "⚠️  CUDA version failed to build (compilation error)"
        fi
    else
        echo "⚠️  CUDA version not available (CUDA toolkit not found)"
    fi
    cd ../..
fi

echo
echo "=== Build Complete ==="
echo
echo "Available executables:"
if [ -f "build/BlackHole3D" ]; then
    echo "  ./build/BlackHole3D     # Enhanced OpenGL version"
fi
if [ -f "build/BlackHole2D" ]; then
    echo "  ./build/BlackHole2D     # 2D lensing demo"
fi
if [ -f "cuda-raytracer/build/BlackHoleCUDA" ]; then
    echo "  ./cuda-raytracer/build/BlackHoleCUDA     # CUDA ray tracer"
fi
echo
echo "Controls:"
echo "  Mouse drag: Rotate camera"
echo "  Mouse wheel: Zoom"
echo "  R: Reset camera"
echo "  P: Cycle presets"
echo "  ESC: Exit"
echo
echo "Ready to explore black holes! 🚀"