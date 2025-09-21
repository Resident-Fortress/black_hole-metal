//
//  GeodesicCompute.metal
//  BlackHoleMetal
//
//  Enhanced Metal compute shader for photorealistic black hole geodesic ray tracing
//  Optimized for Apple Silicon (M4) GPU architecture
//

#include <metal_stdlib>
using namespace metal;

// Enhanced constants for photorealism
constant float SagA_rs = 1.269e10;  // Schwarzschild radius of Sagittarius A*
constant float D_LAMBDA = 1e7;      // Integration step size  
constant float ESCAPE_R = 1e30;     // Escape radius
constant float PI = 3.14159265359;
constant float DOPPLER_FACTOR = 0.3;
constant float REDSHIFT_INTENSITY = 1.5;

// Ray structure for geodesic computation
struct Ray {
    float x, y, z;           // Cartesian coordinates
    float r, theta, phi;     // Spherical coordinates
    float dr, dtheta, dphi;  // Coordinate derivatives
    float d2r, d2phi;        // Second derivatives (output)
    float E, L;              // Conserved quantities (energy and angular momentum)
};

// Enhanced camera uniform buffer
struct CameraUniforms {
    float3 position;
    float3 right;
    float3 up;
    float3 forward;
    float tanHalfFov;
    float aspect;
    bool moving;
    uint width;
    uint height;
};

// Accretion disk parameters
struct DiskUniforms {
    float innerRadius;
    float outerRadius;
    float thickness;
    float temperature;
    float time;          // For animation
};

// Enhanced photorealistic functions
float3 blackbodySpectrum(float temperature) {
    // Simplified blackbody radiation for accretion disk
    float r = clamp(1.0 - exp(-6000.0 / temperature), 0.0, 1.0);
    float g = clamp(1.0 - exp(-4000.0 / temperature), 0.0, 1.0);
    float b = clamp(1.0 - exp(-2000.0 / temperature), 0.0, 1.0);
    return float3(r, g, b);
}

float3 dopplerShift(float3 color, float velocity) {
    // Simulate Doppler shifting of light
    float factor = 1.0 + velocity * DOPPLER_FACTOR;
    return color * factor;
}

float gravitationalRedshift(float r) {
    // Calculate gravitational redshift based on distance from black hole
    return sqrt(max(0.1, 1.0 - SagA_rs / r));
}

float3 generateLightBeam(float3 position, float intensity, float time) {
    // Create visible light beams that interact with spacetime curvature
    float distance = length(position);
    float attenuation = 1.0 / (1.0 + 0.1 * distance * distance / (SagA_rs * SagA_rs));
    
    // Create animated beam pattern
    float beamIntensity = intensity * attenuation;
    float3 beamColor = float3(0.8, 0.9, 1.0) * beamIntensity;
    
    // Add gravitational lensing effect to the beam
    float lensing = 1.0 + SagA_rs / distance;
    beamColor *= lensing;
    
    // Add time-based animation
    float pulse = 1.0 + 0.2 * sin(time * 2.0);
    return beamColor * pulse;
}

float3 calculateDiskColor(float3 position, float r, float time) {
    // Temperature decreases with distance from black hole
    float temperature = 50000.0 * pow(SagA_rs / (r * 1e10), 0.75);
    temperature = clamp(temperature, 2000.0, 100000.0);
    
    // Get blackbody spectrum
    float3 diskColor = blackbodySpectrum(temperature);
    
    // Add gravitational redshift
    float redshift = gravitationalRedshift(r);
    diskColor *= redshift * REDSHIFT_INTENSITY;
    
    // Add turbulence and detail
    float noise = sin(r * 0.0001 + time) * cos(position.x * 0.0001) * sin(position.z * 0.0001);
    diskColor *= (1.0 + 0.3 * noise);
    
    // Add radial brightness variation
    float innerR = SagA_rs * 3.0;
    float outerR = SagA_rs * 20.0;
    float radialFalloff = 1.0 - smoothstep(innerR, outerR, r);
    diskColor *= radialFalloff;
    
    // Add Doppler shifting for rotating disk
    float velocity = sqrt(SagA_rs / r) * 0.3; // Keplerian velocity
    diskColor = dopplerShift(diskColor, velocity);
    
    return diskColor;
}

// Initialize ray from camera and direction
Ray initRay(float3 pos, float3 dir) {
    Ray ray;
    ray.x = pos.x;
    ray.y = pos.y;
    ray.z = pos.z;
    ray.r = length(pos);
    ray.theta = acos(pos.z / ray.r);
    ray.phi = atan2(pos.y, pos.x);

    float dx = dir.x, dy = dir.y, dz = dir.z;
    ray.dr = sin(ray.theta) * cos(ray.phi) * dx + sin(ray.theta) * sin(ray.phi) * dy + cos(ray.theta) * dz;
    ray.dtheta = (cos(ray.theta) * cos(ray.phi) * dx + cos(ray.theta) * sin(ray.phi) * dy - sin(ray.theta) * dz) / ray.r;
    ray.dphi = (-sin(ray.phi) * dx + cos(ray.phi) * dy) / (ray.r * sin(ray.theta));

    ray.L = ray.r * ray.r * sin(ray.theta) * ray.dphi;
    float f = 1.0 - SagA_rs / ray.r;
    float dt_dL = sqrt((ray.dr * ray.dr) / f + ray.r * ray.r * (ray.dtheta * ray.dtheta + sin(ray.theta) * sin(ray.theta) * ray.dphi * ray.dphi));
    ray.E = f * dt_dL;

    return ray;
}

// Geodesic equation right-hand side
void geodesicRHS(Ray ray, thread float3& d1, thread float3& d2) {
    float r = ray.r, theta = ray.theta;
    float dr = ray.dr, dtheta = ray.dtheta, dphi = ray.dphi;
    float f = 1.0 - SagA_rs / r;
    float dt_dL = ray.E / f;

    d1 = float3(dr, dtheta, dphi);
    d2.x = -(SagA_rs / (2.0 * r * r)) * f * dt_dL * dt_dL
         + (SagA_rs / (2.0 * r * r * f)) * dr * dr
         + r * (dtheta * dtheta + sin(theta) * sin(theta) * dphi * dphi);
    d2.y = -2.0 * dr * dtheta / r + sin(theta) * cos(theta) * dphi * dphi;
    d2.z = -2.0 * dr * dphi / r - 2.0 * cos(theta) / sin(theta) * dtheta * dphi;
}

// Enhanced RK4 integration step
void rk4Step(thread Ray& ray, float dL) {
    float3 k1a, k1b, k2a, k2b, k3a, k3b, k4a, k4b;
    
    // Store original values
    float r0 = ray.r, theta0 = ray.theta, phi0 = ray.phi;
    float dr0 = ray.dr, dtheta0 = ray.dtheta, dphi0 = ray.dphi;
    
    // k1
    geodesicRHS(ray, k1a, k1b);
    
    // k2
    ray.r = r0 + 0.5 * dL * k1a.x;
    ray.theta = theta0 + 0.5 * dL * k1a.y;
    ray.phi = phi0 + 0.5 * dL * k1a.z;
    ray.dr = dr0 + 0.5 * dL * k1b.x;
    ray.dtheta = dtheta0 + 0.5 * dL * k1b.y;
    ray.dphi = dphi0 + 0.5 * dL * k1b.z;
    geodesicRHS(ray, k2a, k2b);
    
    // k3
    ray.r = r0 + 0.5 * dL * k2a.x;
    ray.theta = theta0 + 0.5 * dL * k2a.y;
    ray.phi = phi0 + 0.5 * dL * k2a.z;
    ray.dr = dr0 + 0.5 * dL * k2b.x;
    ray.dtheta = dtheta0 + 0.5 * dL * k2b.y;
    ray.dphi = dphi0 + 0.5 * dL * k2b.z;
    geodesicRHS(ray, k3a, k3b);
    
    // k4
    ray.r = r0 + dL * k3a.x;
    ray.theta = theta0 + dL * k3a.y;
    ray.phi = phi0 + dL * k3a.z;
    ray.dr = dr0 + dL * k3b.x;
    ray.dtheta = dtheta0 + dL * k3b.y;
    ray.dphi = dphi0 + dL * k3b.z;
    geodesicRHS(ray, k4a, k4b);
    
    // Final RK4 update
    ray.r = r0 + (dL / 6.0) * (k1a.x + 2.0 * k2a.x + 2.0 * k3a.x + k4a.x);
    ray.theta = theta0 + (dL / 6.0) * (k1a.y + 2.0 * k2a.y + 2.0 * k3a.y + k4a.y);
    ray.phi = phi0 + (dL / 6.0) * (k1a.z + 2.0 * k2a.z + 2.0 * k3a.z + k4a.z);
    ray.dr = dr0 + (dL / 6.0) * (k1b.x + 2.0 * k2b.x + 2.0 * k3b.x + k4b.x);
    ray.dtheta = dtheta0 + (dL / 6.0) * (k1b.y + 2.0 * k2b.y + 2.0 * k3b.y + k4b.y);
    ray.dphi = dphi0 + (dL / 6.0) * (k1b.z + 2.0 * k2b.z + 2.0 * k3b.z + k4b.z);
    
    // Store second derivatives (d2r, d2phi) for output
    ray.d2r = k1b.x;  // d²r/dλ²
    ray.d2phi = k1b.z; // d²φ/dλ²
    
    // Update cartesian coordinates
    ray.x = ray.r * sin(ray.theta) * cos(ray.phi);
    ray.y = ray.r * sin(ray.theta) * sin(ray.phi); 
    ray.z = ray.r * cos(ray.theta);
}

// Check if ray intersects black hole event horizon
bool interceptBlackHole(Ray ray) {
    return ray.r <= SagA_rs;
}

// Check if ray crosses accretion disk
bool crossesAccretionDisk(float3 oldPos, float3 newPos) {
    // Check if ray crosses the equatorial plane (y=0)
    bool crossed = (oldPos.y * newPos.y < 0.0);
    if (!crossed) return false;
    
    // Check if intersection is within disk bounds
    float r = length(float2(newPos.x, newPos.z));
    float innerR = SagA_rs * 3.0;
    float outerR = SagA_rs * 20.0;
    return (r >= innerR && r <= outerR);
}

// Main compute kernel for enhanced geodesic ray tracing
kernel void geodesicRayTrace(constant CameraUniforms& camera [[buffer(0)]],
                            constant DiskUniforms& disk [[buffer(1)]],
                            device Ray* rays [[buffer(2)]],
                            device float4* colors [[buffer(3)]],
                            texture2d<float, access::write> outputTexture [[texture(0)]],
                            uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= camera.width || gid.y >= camera.height) {
        return;
    }
    
    uint index = gid.y * camera.width + gid.x;
    
    // Calculate ray direction from screen coordinates
    float u = (2.0 * (float(gid.x) + 0.5) / float(camera.width) - 1.0) * 
              camera.aspect * camera.tanHalfFov;
    float v = (1.0 - 2.0 * (float(gid.y) + 0.5) / float(camera.height)) * 
              camera.tanHalfFov;
    
    float3 dir = normalize(u * camera.right + v * camera.up + camera.forward);
    
    // Initialize ray
    Ray ray = initRay(camera.position, dir);
    
    // Enhanced ray marching with photorealistic effects
    float4 color = float4(0.0, 0.0, 0.0, 1.0);
    float3 prevPos = float3(ray.x, ray.y, ray.z);
    float3 lightBeamAccumulation = float3(0.0);
    float timeTravel = 0.0;
    
    const int MAX_STEPS = camera.moving ? 40000 : 80000;
    
    for (int step = 0; step < MAX_STEPS; ++step) {
        // Check if ray hits black hole
        if (interceptBlackHole(ray)) {
            // Enhanced event horizon with Hawking radiation glow
            float lambda = length(float3(ray.x, ray.y, ray.z) - camera.position);
            float hawkingGlow = exp(-lambda / (SagA_rs * 1000.0)) * 0.05;
            
            color = float4(
                hawkingGlow * 0.1 + lightBeamAccumulation.x * 0.1,
                hawkingGlow * 0.05 + lightBeamAccumulation.y * 0.1,
                hawkingGlow * 0.2 + lightBeamAccumulation.z * 0.1,
                1.0
            );
            break;
        }
        
        // Accumulate gravitational time dilation
        float gravitationalPotential = -SagA_rs / (2.0 * ray.r);
        timeTravel += gravitationalPotential * D_LAMBDA;
        
        // Add light beam interactions near black hole
        if (ray.r < 5.0 * SagA_rs) {
            float beamStrength = exp(-ray.r / SagA_rs) * 0.1;
            lightBeamAccumulation += generateLightBeam(float3(ray.x, ray.y, ray.z), beamStrength, disk.time);
        }
        
        // Integrate one step
        rk4Step(ray, D_LAMBDA);
        
        // Check disk intersection
        float3 newPos = float3(ray.x, ray.y, ray.z);
        if (crossesAccretionDisk(prevPos, newPos)) {
            float r = length(newPos);
            float3 diskColor = calculateDiskColor(newPos, r, disk.time);
            
            // Add gravitational lensing brightness enhancement
            float lensing = 1.0 + 2.0 * SagA_rs / r;
            diskColor *= lensing;
            
            // Combine with light beams
            diskColor += lightBeamAccumulation * 0.5;
            
            color = float4(diskColor, 1.0);
            break;
        }
        
        prevPos = newPos;
        
        // Check escape condition
        if (ray.r > ESCAPE_R) {
            // Enhanced background with visible light beams and cosmic background
            float3 background = float3(0.01, 0.01, 0.03);
            
            // Add visible light beams in empty space
            background += lightBeamAccumulation;
            
            // Add stars/cosmic background
            float starField = sin(u * 1000.0) * cos(v * 1000.0);
            if (starField > 0.999) {
                background += float3(1.0, 0.9, 0.8) * 0.3;
            }
            
            color = float4(background, 1.0);
            break;
        }
    }
    
    // Apply time dilation color effects
    float timeDilationFactor = 1.0 + timeTravel * 0.00001;
    color.rgb *= timeDilationFactor;
    
    // Write to output texture
    outputTexture.write(color, gid);
    
    // Store ray data for debugging/analysis
    rays[index] = ray;
    colors[index] = color;
}
    float3 up;
    float3 forward;
    float tanHalfFov;
    float aspect;
    int width;
    int height;
};

// Initialize ray from position and direction
Ray initRay(float3 pos, float3 dir) {
    Ray ray;
    
    // Cartesian coordinates
    ray.x = pos.x;
    ray.y = pos.y; 
    ray.z = pos.z;
    
    // Convert to spherical coordinates
    ray.r = length(pos);
    ray.theta = acos(pos.z / ray.r);
    ray.phi = atan2(pos.y, pos.x);
    
    // Calculate coordinate derivatives from direction
    float dx = dir.x, dy = dir.y, dz = dir.z;
    ray.dr = sin(ray.theta) * cos(ray.phi) * dx + 
             sin(ray.theta) * sin(ray.phi) * dy + 
             cos(ray.theta) * dz;
             
    ray.dtheta = (cos(ray.theta) * cos(ray.phi) * dx + 
                  cos(ray.theta) * sin(ray.phi) * dy - 
                  sin(ray.theta) * dz) / ray.r;
                  
    ray.dphi = (-sin(ray.phi) * dx + cos(ray.phi) * dy) / 
               (ray.r * sin(ray.theta));
    
    // Calculate conserved quantities
    ray.L = ray.r * ray.r * sin(ray.theta) * ray.dphi;
    float f = 1.0 - SagA_rs / ray.r;
    float dt_dL = sqrt((ray.dr * ray.dr) / f + 
                       ray.r * ray.r * (ray.dtheta * ray.dtheta + 
                       sin(ray.theta) * sin(ray.theta) * ray.dphi * ray.dphi));
    ray.E = f * dt_dL;
    
    // Initialize second derivatives to zero
    ray.d2r = 0.0;
    ray.d2phi = 0.0;
    
    return ray;
}

// Compute right-hand side of geodesic equations
void geodesicRHS(Ray ray, thread float3& d1, thread float3& d2) {
    float r = ray.r;
    float theta = ray.theta;
    float dr = ray.dr;
    float dtheta = ray.dtheta;
    float dphi = ray.dphi;
    
    float f = 1.0 - SagA_rs / r;
    float dt_dL = ray.E / f;
    
    // First derivatives
    d1 = float3(dr, dtheta, dphi);
    
    // Second derivatives from 3D Schwarzschild null geodesics
    d2.x = -(SagA_rs / (2.0 * r * r)) * f * dt_dL * dt_dL +
           (SagA_rs / (2.0 * r * r * f)) * dr * dr +
           r * (dtheta * dtheta + sin(theta) * sin(theta) * dphi * dphi);
    
    d2.y = -2.0 * dr * dtheta / r + sin(theta) * cos(theta) * dphi * dphi;
    
    d2.z = -2.0 * dr * dphi / r - 2.0 * cos(theta) / sin(theta) * dtheta * dphi;
}

// 4th order Runge-Kutta integration step
void rk4Step(thread Ray& ray, float dL) {
    float3 k1a, k1b, k2a, k2b, k3a, k3b, k4a, k4b;
    float3 temp_d1, temp_d2;
    
    // Store initial state
    float r0 = ray.r, theta0 = ray.theta, phi0 = ray.phi;
    float dr0 = ray.dr, dtheta0 = ray.dtheta, dphi0 = ray.dphi;
    
    // k1
    geodesicRHS(ray, k1a, k1b);
    
    // k2 - evaluate at midpoint
    ray.r = r0 + dL * k1a.x * 0.5;
    ray.theta = theta0 + dL * k1a.y * 0.5; 
    ray.phi = phi0 + dL * k1a.z * 0.5;
    ray.dr = dr0 + dL * k1b.x * 0.5;
    ray.dtheta = dtheta0 + dL * k1b.y * 0.5;
    ray.dphi = dphi0 + dL * k1b.z * 0.5;
    geodesicRHS(ray, k2a, k2b);
    
    // k3 - evaluate at midpoint with k2 
    ray.r = r0 + dL * k2a.x * 0.5;
    ray.theta = theta0 + dL * k2a.y * 0.5;
    ray.phi = phi0 + dL * k2a.z * 0.5; 
    ray.dr = dr0 + dL * k2b.x * 0.5;
    ray.dtheta = dtheta0 + dL * k2b.y * 0.5;
    ray.dphi = dphi0 + dL * k2b.z * 0.5;
    geodesicRHS(ray, k3a, k3b);
    
    // k4 - evaluate at endpoint
    ray.r = r0 + dL * k3a.x;
    ray.theta = theta0 + dL * k3a.y;
    ray.phi = phi0 + dL * k3a.z;
    ray.dr = dr0 + dL * k3b.x;
    ray.dtheta = dtheta0 + dL * k3b.y;
    ray.dphi = dphi0 + dL * k3b.z;
    geodesicRHS(ray, k4a, k4b);
    
    // Final RK4 update
    ray.r = r0 + (dL / 6.0) * (k1a.x + 2.0 * k2a.x + 2.0 * k3a.x + k4a.x);
    ray.theta = theta0 + (dL / 6.0) * (k1a.y + 2.0 * k2a.y + 2.0 * k3a.y + k4a.y);
    ray.phi = phi0 + (dL / 6.0) * (k1a.z + 2.0 * k2a.z + 2.0 * k3a.z + k4a.z);
    ray.dr = dr0 + (dL / 6.0) * (k1b.x + 2.0 * k2b.x + 2.0 * k3b.x + k4b.x);
    ray.dtheta = dtheta0 + (dL / 6.0) * (k1b.y + 2.0 * k2b.y + 2.0 * k3b.y + k4b.y);
    ray.dphi = dphi0 + (dL / 6.0) * (k1b.z + 2.0 * k2b.z + 2.0 * k3b.z + k4b.z);
    
    // Store second derivatives (d2r, d2phi) for output
    ray.d2r = k1b.x;  // d²r/dλ²
    ray.d2phi = k1b.z; // d²φ/dλ²
    
    // Update cartesian coordinates
    ray.x = ray.r * sin(ray.theta) * cos(ray.phi);
    ray.y = ray.r * sin(ray.theta) * sin(ray.phi); 
    ray.z = ray.r * cos(ray.theta);
}

// Check if ray intersects black hole event horizon
bool interceptBlackHole(Ray ray) {
    return ray.r <= SagA_rs;
}

// Main compute kernel for geodesic ray tracing
kernel void geodesicRayTrace(constant CameraUniforms& camera [[buffer(0)]],
                            device Ray* rays [[buffer(1)]],
                            device float4* colors [[buffer(2)]],
                            uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= camera.width || gid.y >= camera.height) {
        return;
    }
    
    uint index = gid.y * camera.width + gid.x;
    
    // Calculate ray direction from screen coordinates
    float u = (2.0 * (float(gid.x) + 0.5) / float(camera.width) - 1.0) * 
              camera.aspect * camera.tanHalfFov;
    float v = (1.0 - 2.0 * (float(gid.y) + 0.5) / float(camera.height)) * 
              camera.tanHalfFov;
    
    float3 dir = normalize(u * camera.right + v * camera.up + camera.forward);
    
    // Initialize ray
    Ray ray = initRay(camera.position, dir);
    
    // March ray through geodesic
    float4 color = float4(0.0, 0.0, 0.0, 1.0);
    const int MAX_STEPS = 10000;
    
    for (int step = 0; step < MAX_STEPS; ++step) {
        // Check if ray hits black hole
        if (interceptBlackHole(ray)) {
            color = float4(1.0, 0.0, 0.0, 1.0); // Red for black hole
            break;
        }
        
        // Integrate one step
        rk4Step(ray, D_LAMBDA);
        
        // Check escape condition
        if (ray.r > ESCAPE_R) {
            color = float4(0.0, 0.0, 1.0, 1.0); // Blue for escaped rays
            break;
        }
    }
    
    // Store results
    rays[index] = ray;
    colors[index] = color;
}