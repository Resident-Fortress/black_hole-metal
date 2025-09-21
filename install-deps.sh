#!/bin/bash

# Installation script for black hole simulation dependencies
# Supports Ubuntu/Debian and derivatives

set -e

echo "=== Black Hole Simulation - Dependency Installation ==="
echo "This script will install the required dependencies for building the project."
echo

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo "Cannot detect OS. This script supports Ubuntu/Debian systems."
    exit 1
fi

echo "Detected OS: $OS $VER"
echo

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Update package list
echo "Updating package list..."
$SUDO apt update

# Install basic build tools
echo "Installing build essentials..."
$SUDO apt install -y build-essential cmake git

# Install OpenGL and graphics libraries
echo "Installing OpenGL and graphics dependencies..."
$SUDO apt install -y \
    libgl1-mesa-dev \
    libglew-dev \
    libglfw3-dev \
    libglm-dev \
    pkg-config

# Optional: Install CUDA if NVIDIA GPU is detected
if command -v nvidia-smi &> /dev/null; then
    echo
    echo "NVIDIA GPU detected. Would you like to install CUDA toolkit? (y/n)"
    echo "This is required for the CUDA ray tracer version."
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Installing CUDA toolkit..."
        
        # Add NVIDIA package repository
        wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb
        $SUDO dpkg -i cuda-keyring_1.0-1_all.deb
        $SUDO apt update
        
        # Install CUDA toolkit
        $SUDO apt install -y cuda-toolkit-12-0
        
        echo "CUDA installed. You may need to log out and back in for PATH changes to take effect."
        echo "Or run: export PATH=/usr/local/cuda-12.0/bin:\$PATH"
        
        rm -f cuda-keyring_1.0-1_all.deb
    fi
else
    echo "No NVIDIA GPU detected. Skipping CUDA installation."
fi

echo
echo "=== Installation Complete ==="
echo
echo "Dependencies installed successfully!"
echo
echo "To build the project:"
echo "  mkdir build && cd build"
echo "  cmake .."
echo "  make -j\$(nproc)"
echo
echo "To run:"
echo "  ./BlackHole3D     # Enhanced OpenGL version"
echo "  ./BlackHole2D     # 2D lensing demo"
echo
if command -v nvidia-smi &> /dev/null && [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "For CUDA version:"
    echo "  cd cuda-raytracer && mkdir build && cd build"
    echo "  cmake .. && make -j\$(nproc)"
    echo "  ./BlackHoleCUDA"
    echo
fi
echo "Enjoy your photorealistic black hole simulation! 🚀"