//
//  GeodesicCompute.metal
//  BlackHoleMetal
//
//  Metal compute shader for black hole geodesic ray tracing
//

#include <metal_stdlib>
using namespace metal;

// Constants
constant float SagA_rs = 1.269e10;  // Schwarzschild radius of Sagittarius A*
constant float D_LAMBDA = 1e7;      // Integration step size
constant float ESCAPE_R = 1e30;     // Escape radius

// Ray structure for geodesic computation
struct Ray {
    // Cartesian coordinates
    float x, y, z;

    // Spherical coordinates
    float r, theta, phi;

    // First derivatives
    float dr, dtheta, dphi;

    // Second derivatives (outputs)
    float d2r, d2phi;

    // Conserved quantities
    float E, L;
};

// Camera uniform buffer - must match Swift layout in Ray.swift
struct CameraUniforms {
    float3 position;
    float3 right;
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

    // Initialize second derivatives
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
    ray.d2r = k1b.x;   // d²r/dλ²
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

// Compute realistic cosmic background with procedural star field
float4 computeCosmicBackground(Ray ray, float3 dir) {
    // Base cosmic microwave background color (very faint red-orange)
    float4 cmbColor = float4(0.002, 0.001, 0.0005, 1.0);
    
    // Procedural star field based on ray direction
    float3 p = normalize(dir) * 1000.0;
    
    // Multiple octaves of noise for realistic star distribution
    float starIntensity = 0.0;
    float scale = 1.0;
    
    for (int i = 0; i < 4; i++) {
        float3 noiseCoord = p * scale;
        float noise = sin(noiseCoord.x * 12.9898 + noiseCoord.y * 78.233 + noiseCoord.z * 37.719) * 43758.5453;
        noise = fract(noise);
        
        // Create star-like points
        if (noise > 0.998) {
            float brightness = (noise - 0.998) * 500.0; // Very bright stars
            starIntensity += brightness * (1.0 / scale);
        } else if (noise > 0.995) {
            float brightness = (noise - 0.995) * 100.0; // Medium stars  
            starIntensity += brightness * (1.0 / scale);
        } else if (noise > 0.99) {
            float brightness = (noise - 0.99) * 20.0; // Dim stars
            starIntensity += brightness * (1.0 / scale);
        }
        
        scale *= 2.0;
    }
    
    // Add gravitational redshift effect based on how close the ray got to the black hole
    float minDistance = min(ray.r, SagA_rs * 10.0); // Track closest approach
    float redshiftFactor = sqrt(1.0 - SagA_rs / minDistance);
    
    // Apply redshift to star colors (shift toward red end of spectrum)
    float4 starColor = float4(starIntensity * redshiftFactor, 
                             starIntensity * redshiftFactor * 0.8, 
                             starIntensity * redshiftFactor * 0.6, 
                             1.0);
    
    return cmbColor + starColor;
}

// Compute accretion disk contribution with temperature-based blackbody radiation
float4 computeAccretionDisk(Ray ray, float3 dir) {
    // Simple accretion disk model - disk in xy plane
    float diskRadius = SagA_rs * 6.0; // Innermost stable circular orbit region
    float diskThickness = SagA_rs * 0.1;
    
    // Check if ray passes through disk region
    if (abs(ray.z) < diskThickness && ray.r > SagA_rs * 3.0 && ray.r < diskRadius) {
        // Temperature decreases with distance from black hole  
        float temperature = 1e6 / pow(ray.r / SagA_rs, 0.75); // Kelvin
        
        // Simplified blackbody radiation (Wien's displacement law)
        float lambda_max = 2.898e-3 / temperature; // Peak wavelength in meters
        
        // Convert to RGB approximation
        float4 diskColor;
        if (lambda_max < 380e-9) {
            // Ultraviolet - appears white-blue
            diskColor = float4(0.8, 0.9, 1.0, 1.0);
        } else if (lambda_max < 450e-9) {
            // Blue
            diskColor = float4(0.2, 0.4, 1.0, 1.0);
        } else if (lambda_max < 550e-9) {
            // Green-yellow  
            diskColor = float4(0.5, 1.0, 0.3, 1.0);
        } else if (lambda_max < 700e-9) {
            // Orange-red
            diskColor = float4(1.0, 0.5, 0.1, 1.0);
        } else {
            // Infrared - appears deep red
            diskColor = float4(0.8, 0.1, 0.0, 1.0);
        }
        
        // Intensity based on temperature and viewing angle
        float intensity = temperature / 1e6; // Normalize
        diskColor *= intensity;
        
        return diskColor;
    }
    
    return float4(0.0, 0.0, 0.0, 0.0); // No contribution
}

// Main compute kernel for geodesic ray tracing
kernel void geodesicRayTrace(constant CameraUniforms& camera [[buffer(0)]],
                             device Ray* rays [[buffer(1)]],
                             device float4* colors [[buffer(2)]],
                             uint2 gid [[thread_position_in_grid]]) {

    if (gid.x >= (uint)camera.width || gid.y >= (uint)camera.height) {
        return;
    }

    uint index = gid.y * (uint)camera.width + gid.x;

    // Calculate ray direction from screen coordinates
    float u = (2.0 * (float(gid.x) + 0.5) / float(camera.width) - 1.0) *
              camera.aspect * camera.tanHalfFov;
    float v = (1.0 - 2.0 * (float(gid.y) + 0.5) / float(camera.height)) *
              camera.tanHalfFov;

    float3 dir = normalize(u * camera.right + v * camera.up + camera.forward);

    // Initialize ray
    Ray ray = initRay(camera.position, dir);

    // March ray through geodesic with enhanced realistic rendering
    float4 color = float4(0.0, 0.0, 0.0, 1.0);
    float4 accumulatedColor = float4(0.0, 0.0, 0.0, 0.0);
    const int MAX_STEPS = 10000;
    float closestApproach = ESCAPE_R;

    for (int step = 0; step < MAX_STEPS; ++step) {
        // Track closest approach to black hole for redshift calculation
        closestApproach = min(closestApproach, ray.r);
        
        // Check if ray hits black hole
        if (interceptBlackHole(ray)) {
            color = float4(0.0, 0.0, 0.0, 1.0); // Black for black hole (singularity)
            break;
        }

        // Check for accretion disk interaction
        float4 diskContribution = computeAccretionDisk(ray, dir);
        if (diskContribution.w > 0.0) {
            // Add disk emission with proper alpha blending
            accumulatedColor.rgb += diskContribution.rgb * diskContribution.w;
            accumulatedColor.w = min(accumulatedColor.w + diskContribution.w, 1.0);
        }

        // Integrate one step  
        rk4Step(ray, D_LAMBDA);

        // Check escape condition
        if (ray.r > ESCAPE_R) {
            // Implement realistic cosmic background with realistic lighting
            color = computeCosmicBackground(ray, dir);
            
            // Apply gravitational redshift based on closest approach
            float redshiftFactor = sqrt(1.0 - SagA_rs / closestApproach);
            color.rgb *= redshiftFactor;
            
            break;
        }
    }
    
    // Combine background and accretion disk contributions
    color.rgb = color.rgb * (1.0 - accumulatedColor.w) + accumulatedColor.rgb;

    // Store results
    rays[index] = ray;
    colors[index] = color;
}
