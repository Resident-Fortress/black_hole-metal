#pragma once

// OpenGL headers must be included in this specific order
#include <GL/glew.h>
#include <GLFW/glfw3.h>

// CUDA headers (after OpenGL)
#include <cuda_runtime.h>
#include <cuda_gl_interop.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <vector>
#include <memory>

// CUDA constants
constexpr float SAGA_RS = 1.269e10f;
constexpr float D_LAMBDA = 1e7f;
constexpr float ESCAPE_R = 1e30f;
constexpr int MAX_RAY_STEPS = 100000;

// Ray structure for CUDA kernels
struct CudaRay {
    float x, y, z;           // Cartesian coordinates
    float r, theta, phi;     // Spherical coordinates  
    float dr, dtheta, dphi;  // Coordinate derivatives
    float E, L;              // Conserved quantities
};

// Camera structure
struct CudaCamera {
    glm::vec3 position;
    glm::vec3 right;
    glm::vec3 up;
    glm::vec3 forward;
    float tanHalfFov;
    float aspect;
    bool moving;
};

// Accretion disk parameters
struct AccretionDisk {
    float innerRadius;
    float outerRadius;
    float thickness;
    float temperature;
};

// Black hole parameters
struct BlackHole {
    glm::vec3 position;
    float mass;
    float schwarzschildRadius;
};

// CUDA kernel launch parameters
struct CudaLaunchParams {
    dim3 blockSize;
    dim3 gridSize;
    int width;
    int height;
};

// Forward declarations
class CudaRenderer;
class CudaCamera;
class OpenGLInterop;

// CUDA kernel functions (implemented in cuda_kernels.cu)
extern "C" {
    void launchRaytraceKernel(
        float4* output,
        const CudaCamera& camera,
        const AccretionDisk& disk,
        const BlackHole& blackHole,
        int width, int height,
        cudaStream_t stream = 0
    );
    
    void launchPhotorealisticKernel(
        float4* output,
        const CudaCamera& camera,
        const AccretionDisk& disk,
        const BlackHole& blackHole,
        int width, int height,
        float time,
        cudaStream_t stream = 0
    );
}

// Error checking macros
#define CUDA_CHECK(call) \
    do { \
        cudaError_t err = call; \
        if (err != cudaSuccess) { \
            fprintf(stderr, "CUDA error at %s:%d - %s\n", __FILE__, __LINE__, cudaGetErrorString(err)); \
            exit(1); \
        } \
    } while(0)

#define GL_CHECK() \
    do { \
        GLenum err = glGetError(); \
        if (err != GL_NO_ERROR) { \
            fprintf(stderr, "OpenGL error at %s:%d - %d\n", __FILE__, __LINE__, err); \
            exit(1); \
        } \
    } while(0)
