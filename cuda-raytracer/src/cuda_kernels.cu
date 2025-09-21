#include "../include/black_hole_cuda.h"
#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <math_constants.h>

// Device constants
__constant__ float d_SagA_rs = SAGA_RS;
__constant__ float d_D_LAMBDA = D_LAMBDA;
__constant__ float d_ESCAPE_R = ESCAPE_R;

// Device utility functions
__device__ inline float3 make_float3_from_glm(const glm::vec3& v) {
    return make_float3(v.x, v.y, v.z);
}

__device__ inline float length_f3(const float3& v) {
    return sqrtf(v.x * v.x + v.y * v.y + v.z * v.z);
}

__device__ inline float3 normalize_f3(const float3& v) {
    float len = length_f3(v);
    return make_float3(v.x / len, v.y / len, v.z / len);
}

// Enhanced blackbody spectrum calculation
__device__ float3 blackbodySpectrum(float temperature) {
    // Simplified blackbody radiation using Planck's law approximation
    float r = fmaxf(0.0f, fminf(1.0f, 1.0f - expf(-6000.0f / temperature)));
    float g = fmaxf(0.0f, fminf(1.0f, 1.0f - expf(-4000.0f / temperature)));
    float b = fmaxf(0.0f, fminf(1.0f, 1.0f - expf(-2000.0f / temperature)));
    return make_float3(r, g, b);
}

// Gravitational redshift calculation
__device__ float gravitationalRedshift(float r) {
    return sqrtf(fmaxf(0.1f, 1.0f - d_SagA_rs / r));
}

// Doppler shift simulation
__device__ float3 dopplerShift(const float3& color, float velocity) {
    float factor = 1.0f + velocity * 0.3f;
    return make_float3(color.x * factor, color.y * factor, color.z * factor);
}

// Initialize ray from camera parameters
__device__ CudaRay initRay(const float3& pos, const float3& dir) {
    CudaRay ray;
    ray.x = pos.x;
    ray.y = pos.y; 
    ray.z = pos.z;
    ray.r = length_f3(pos);
    ray.theta = acosf(pos.z / ray.r);
    ray.phi = atan2f(pos.y, pos.x);

    // Calculate derivatives
    ray.dr = sinf(ray.theta) * cosf(ray.phi) * dir.x + 
             sinf(ray.theta) * sinf(ray.phi) * dir.y + 
             cosf(ray.theta) * dir.z;
    ray.dtheta = (cosf(ray.theta) * cosf(ray.phi) * dir.x + 
                  cosf(ray.theta) * sinf(ray.phi) * dir.y - 
                  sinf(ray.theta) * dir.z) / ray.r;
    ray.dphi = (-sinf(ray.phi) * dir.x + cosf(ray.phi) * dir.y) / 
               (ray.r * sinf(ray.theta));

    // Calculate conserved quantities
    ray.L = ray.r * ray.r * sinf(ray.theta) * ray.dphi;
    float f = 1.0f - d_SagA_rs / ray.r;
    float dt_dL = sqrtf((ray.dr * ray.dr) / f + 
                        ray.r * ray.r * (ray.dtheta * ray.dtheta + 
                        sinf(ray.theta) * sinf(ray.theta) * ray.dphi * ray.dphi));
    ray.E = f * dt_dL;

    return ray;
}

// Geodesic equation right-hand side
__device__ void geodesicRHS(const CudaRay& ray, float3& d1, float3& d2) {
    float r = ray.r;
    float theta = ray.theta;
    float dr = ray.dr;
    float dtheta = ray.dtheta;
    float dphi = ray.dphi;
    float f = 1.0f - d_SagA_rs / r;
    float dt_dL = ray.E / f;

    d1 = make_float3(dr, dtheta, dphi);
    
    d2.x = -(d_SagA_rs / (2.0f * r * r)) * f * dt_dL * dt_dL +
           (d_SagA_rs / (2.0f * r * r * f)) * dr * dr +
           r * (dtheta * dtheta + sinf(theta) * sinf(theta) * dphi * dphi);
    d2.y = -2.0f * dr * dtheta / r + sinf(theta) * cosf(theta) * dphi * dphi;
    d2.z = -2.0f * dr * dphi / r - 2.0f * cosf(theta) / sinf(theta) * dtheta * dphi;
}

// Runge-Kutta 4th order integration step
__device__ void rk4Step(CudaRay& ray, float dL) {
    float3 k1a, k1b, k2a, k2b, k3a, k3b, k4a, k4b;
    
    // Store original values
    float r0 = ray.r, theta0 = ray.theta, phi0 = ray.phi;
    float dr0 = ray.dr, dtheta0 = ray.dtheta, dphi0 = ray.dphi;
    
    // k1
    geodesicRHS(ray, k1a, k1b);
    
    // k2
    ray.r = r0 + 0.5f * dL * k1a.x;
    ray.theta = theta0 + 0.5f * dL * k1a.y;
    ray.phi = phi0 + 0.5f * dL * k1a.z;
    ray.dr = dr0 + 0.5f * dL * k1b.x;
    ray.dtheta = dtheta0 + 0.5f * dL * k1b.y;
    ray.dphi = dphi0 + 0.5f * dL * k1b.z;
    geodesicRHS(ray, k2a, k2b);
    
    // k3
    ray.r = r0 + 0.5f * dL * k2a.x;
    ray.theta = theta0 + 0.5f * dL * k2a.y;
    ray.phi = phi0 + 0.5f * dL * k2a.z;
    ray.dr = dr0 + 0.5f * dL * k2b.x;
    ray.dtheta = dtheta0 + 0.5f * dL * k2b.y;
    ray.dphi = dphi0 + 0.5f * dL * k2b.z;
    geodesicRHS(ray, k3a, k3b);
    
    // k4
    ray.r = r0 + dL * k3a.x;
    ray.theta = theta0 + dL * k3a.y;
    ray.phi = phi0 + dL * k3a.z;
    ray.dr = dr0 + dL * k3b.x;
    ray.dtheta = dtheta0 + dL * k3b.y;
    ray.dphi = dphi0 + dL * k3b.z;
    geodesicRHS(ray, k4a, k4b);
    
    // Final update
    ray.r = r0 + (dL / 6.0f) * (k1a.x + 2.0f * k2a.x + 2.0f * k3a.x + k4a.x);
    ray.theta = theta0 + (dL / 6.0f) * (k1a.y + 2.0f * k2a.y + 2.0f * k3a.y + k4a.y);
    ray.phi = phi0 + (dL / 6.0f) * (k1a.z + 2.0f * k2a.z + 2.0f * k3a.z + k4a.z);
    ray.dr = dr0 + (dL / 6.0f) * (k1b.x + 2.0f * k2b.x + 2.0f * k3b.x + k4b.x);
    ray.dtheta = dtheta0 + (dL / 6.0f) * (k1b.y + 2.0f * k2b.y + 2.0f * k3b.y + k4b.y);
    ray.dphi = dphi0 + (dL / 6.0f) * (k1b.z + 2.0f * k2b.z + 2.0f * k3b.z + k4b.z);
    
    // Update Cartesian coordinates
    ray.x = ray.r * sinf(ray.theta) * cosf(ray.phi);
    ray.y = ray.r * sinf(ray.theta) * sinf(ray.phi);
    ray.z = ray.r * cosf(ray.theta);
}

// Check if ray hits black hole event horizon
__device__ bool interceptBlackHole(const CudaRay& ray) {
    return ray.r <= d_SagA_rs;
}

// Check if ray crosses accretion disk
__device__ bool crossesAccretionDisk(const float3& oldPos, const float3& newPos, 
                                   const AccretionDisk& disk) {
    // Check if ray crosses the equatorial plane (y=0)
    bool crossed = (oldPos.y * newPos.y < 0.0f);
    if (!crossed) return false;
    
    // Check if intersection is within disk bounds
    float r = sqrtf(newPos.x * newPos.x + newPos.z * newPos.z);
    return (r >= disk.innerRadius && r <= disk.outerRadius);
}

// Calculate enhanced accretion disk color with realistic physics
__device__ float4 calculateDiskColor(const float3& position, const AccretionDisk& disk, float time) {
    float r = length_f3(position);
    
    // Temperature decreases with distance (T ∝ r^-0.75 for thin disk)
    float temperature = 50000.0f * powf(d_SagA_rs / (r * 1e10f), 0.75f);
    temperature = fmaxf(2000.0f, fminf(100000.0f, temperature));
    
    // Get blackbody spectrum
    float3 diskColor = blackbodySpectrum(temperature);
    
    // Apply gravitational redshift 
    float redshift = gravitationalRedshift(r);
    diskColor.x *= redshift * 1.5f;
    diskColor.y *= redshift * 1.5f;
    diskColor.z *= redshift * 1.5f;
    
    // Add turbulence and detail using noise
    float noise = sinf(r * 0.0001f + time) * cosf(position.x * 0.0001f) * sinf(position.z * 0.0001f);
    float turbulence = 1.0f + 0.3f * noise;
    diskColor.x *= turbulence;
    diskColor.y *= turbulence;
    diskColor.z *= turbulence;
    
    // Radial brightness falloff
    float radialFalloff = 1.0f - smoothstep(disk.innerRadius, disk.outerRadius, r);
    diskColor.x *= radialFalloff;
    diskColor.y *= radialFalloff;
    diskColor.z *= radialFalloff;
    
    // Add Doppler shifting for rotating disk
    float velocity = sqrtf(d_SagA_rs / r) * 0.3f; // Keplerian velocity approximation
    diskColor = dopplerShift(diskColor, velocity);
    
    return make_float4(diskColor.x, diskColor.y, diskColor.z, 1.0f);
}

// Generate visible light beams
__device__ float3 generateLightBeam(const float3& position, float intensity, float time) {
    float distance = length_f3(position);
    float attenuation = 1.0f / (1.0f + 0.1f * distance * distance / (d_SagA_rs * d_SagA_rs));
    
    // Create animated beam pattern
    float beamIntensity = intensity * attenuation;
    float3 beamColor = make_float3(0.8f, 0.9f, 1.0f);
    beamColor.x *= beamIntensity;
    beamColor.y *= beamIntensity;
    beamColor.z *= beamIntensity;
    
    // Add gravitational lensing effect
    float lensing = 1.0f + d_SagA_rs / distance;
    beamColor.x *= lensing;
    beamColor.y *= lensing;
    beamColor.z *= lensing;
    
    // Add time-based animation
    float pulse = 1.0f + 0.2f * sinf(time * 2.0f);
    beamColor.x *= pulse;
    beamColor.y *= pulse;
    beamColor.z *= pulse;
    
    return beamColor;
}

// Main photorealistic ray tracing kernel
__global__ void photorealisticRaytraceKernel(
    float4* output,
    CudaCamera camera,
    AccretionDisk disk,
    BlackHole blackHole,
    int width, int height,
    float time
) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    
    if (x >= width || y >= height) return;
    
    int idx = y * width + x;
    
    // Calculate ray direction from screen coordinates
    float u = (2.0f * (x + 0.5f) / width - 1.0f) * camera.aspect * camera.tanHalfFov;
    float v = (1.0f - 2.0f * (y + 0.5f) / height) * camera.tanHalfFov;
    
    float3 camPos = make_float3_from_glm(camera.position);
    float3 camRight = make_float3_from_glm(camera.right);
    float3 camUp = make_float3_from_glm(camera.up);
    float3 camForward = make_float3_from_glm(camera.forward);
    
    float3 dir = normalize_f3(make_float3(
        u * camRight.x - v * camUp.x + camForward.x,
        u * camRight.y - v * camUp.y + camForward.y,
        u * camRight.z - v * camUp.z + camForward.z
    ));
    
    // Initialize ray
    CudaRay ray = initRay(camPos, dir);
    
    float4 color = make_float4(0.0f, 0.0f, 0.0f, 1.0f);
    float3 prevPos = make_float3(ray.x, ray.y, ray.z);
    float3 lightBeamAccumulation = make_float3(0.0f, 0.0f, 0.0f);
    float timeTravel = 0.0f;
    
    bool hitBlackHole = false;
    bool hitDisk = false;
    
    int maxSteps = camera.moving ? 40000 : 80000;
    
    // Ray marching loop
    for (int step = 0; step < maxSteps; ++step) {
        // Check black hole collision
        if (interceptBlackHole(ray)) {
            hitBlackHole = true;
            break;
        }
        
        // Accumulate gravitational time dilation
        float gravitationalPotential = -d_SagA_rs / (2.0f * ray.r);
        timeTravel += gravitationalPotential * d_D_LAMBDA;
        
        // Add light beam interactions near black hole
        if (ray.r < 5.0f * d_SagA_rs) {
            float beamStrength = expf(-ray.r / d_SagA_rs) * 0.1f;
            float3 beamContrib = generateLightBeam(make_float3(ray.x, ray.y, ray.z), beamStrength, time);
            lightBeamAccumulation.x += beamContrib.x;
            lightBeamAccumulation.y += beamContrib.y;
            lightBeamAccumulation.z += beamContrib.z;
        }
        
        // Integration step
        rk4Step(ray, d_D_LAMBDA);
        
        // Check disk intersection
        float3 newPos = make_float3(ray.x, ray.y, ray.z);
        if (crossesAccretionDisk(prevPos, newPos, disk)) {
            hitDisk = true;
            break;
        }
        
        prevPos = newPos;
        
        // Check escape condition
        if (ray.r > d_ESCAPE_R) break;
    }
    
    // Color calculation based on what was hit
    if (hitDisk) {
        float4 diskColor = calculateDiskColor(make_float3(ray.x, ray.y, ray.z), disk, time);
        
        // Add gravitational lensing brightness enhancement
        float lensing = 1.0f + 2.0f * d_SagA_rs / ray.r;
        diskColor.x *= lensing;
        diskColor.y *= lensing;
        diskColor.z *= lensing;
        
        // Combine with light beams
        diskColor.x += lightBeamAccumulation.x * 0.5f;
        diskColor.y += lightBeamAccumulation.y * 0.5f;
        diskColor.z += lightBeamAccumulation.z * 0.5f;
        
        color = diskColor;
        
    } else if (hitBlackHole) {
        // Enhanced event horizon with Hawking radiation glow
        float lambda = length_f3(make_float3(ray.x - camPos.x, ray.y - camPos.y, ray.z - camPos.z));
        float hawkingGlow = expf(-lambda / (d_SagA_rs * 1000.0f)) * 0.05f;
        
        color = make_float4(
            hawkingGlow * 0.1f + lightBeamAccumulation.x * 0.1f,
            hawkingGlow * 0.05f + lightBeamAccumulation.y * 0.1f,
            hawkingGlow * 0.2f + lightBeamAccumulation.z * 0.1f,
            1.0f
        );
        
    } else {
        // Enhanced background with visible light beams and cosmic background
        float3 background = make_float3(0.01f, 0.01f, 0.03f);
        
        // Add visible light beams in empty space
        background.x += lightBeamAccumulation.x;
        background.y += lightBeamAccumulation.y;
        background.z += lightBeamAccumulation.z;
        
        // Add stars/cosmic background
        float starField = sinf(u * 1000.0f) * cosf(v * 1000.0f);
        if (starField > 0.999f) {
            background.x += 0.3f;
            background.y += 0.27f;
            background.z += 0.24f;
        }
        
        color = make_float4(background.x, background.y, background.z, 1.0f);
    }
    
    // Apply time dilation color effects
    float timeDilationFactor = 1.0f + timeTravel * 0.00001f;
    color.x *= timeDilationFactor;
    color.y *= timeDilationFactor;
    color.z *= timeDilationFactor;
    
    output[idx] = color;
}

// C interface functions
extern "C" {
    void launchPhotorealisticKernel(
        float4* output,
        const CudaCamera& camera,
        const AccretionDisk& disk,
        const BlackHole& blackHole,
        int width, int height,
        float time,
        cudaStream_t stream
    ) {
        dim3 blockSize(16, 16);
        dim3 gridSize((width + blockSize.x - 1) / blockSize.x,
                      (height + blockSize.y - 1) / blockSize.y);
        
        photorealisticRaytraceKernel<<<gridSize, blockSize, 0, stream>>>(
            output, camera, disk, blackHole, width, height, time
        );
    }
}