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
