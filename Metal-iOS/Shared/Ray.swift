//
//  Ray.swift
//  BlackHoleMetal
//
//  Ray structure definitions and utilities for black hole geodesic computation
//

import Foundation
import simd

/// Ray structure for geodesic computation - matches Metal shader layout
struct Ray {
    // Cartesian coordinates
    var x: Float = 0.0
    var y: Float = 0.0
    var z: Float = 0.0
    
    // Spherical coordinates
    var r: Float = 0.0
    var theta: Float = 0.0
    var phi: Float = 0.0
    
    // First derivatives
    var dr: Float = 0.0
    var dtheta: Float = 0.0
    var dphi: Float = 0.0
    
    // Second derivatives (computed outputs)
    var d2r: Float = 0.0
    var d2phi: Float = 0.0
    
    // Conserved quantities
    var E: Float = 0.0  // Energy
    var L: Float = 0.0  // Angular momentum
    
    /// Initialize ray from position and direction vectors
    init(position: simd_float3, direction: simd_float3) {
        // Set cartesian coordinates
        self.x = position.x
        self.y = position.y
        self.z = position.z
        
        // Convert to spherical coordinates
        self.r = length(position)
        self.theta = acos(position.z / self.r)
        self.phi = atan2(position.y, position.x)
        
        // Calculate coordinate derivatives
        let dx = direction.x
        let dy = direction.y
        let dz = direction.z
        
        self.dr = sin(theta) * cos(phi) * dx + 
                  sin(theta) * sin(phi) * dy + 
                  cos(theta) * dz
                  
        self.dtheta = (cos(theta) * cos(phi) * dx + 
                       cos(theta) * sin(phi) * dy - 
                       sin(theta) * dz) / r
                       
        self.dphi = (-sin(phi) * dx + cos(phi) * dy) / 
                    (r * sin(theta))
        
        // Calculate conserved quantities
        let SagA_rs: Float = 1.269e10  // Schwarzschild radius
        self.L = r * r * sin(theta) * dphi
        let f = 1.0 - SagA_rs / r
        let dt_dL = sqrt((dr * dr) / f + 
                         r * r * (dtheta * dtheta + 
                         sin(theta) * sin(theta) * dphi * dphi))
        self.E = f * dt_dL
        
        // Initialize second derivatives
        self.d2r = 0.0
        self.d2phi = 0.0
    }
    
    /// Get cartesian position as simd_float3
    var position: simd_float3 {
        return simd_float3(x, y, z)
    }
    
    /// Get spherical position as simd_float3 (r, theta, phi)
    var sphericalPosition: simd_float3 {
        return simd_float3(r, theta, phi)
    }
    
    /// Get first derivatives as simd_float3 (dr, dtheta, dphi)
    var firstDerivatives: simd_float3 {
        return simd_float3(dr, dtheta, dphi)
    }
    
    /// Get second derivatives as simd_float2 (d2r, d2phi)
    var secondDerivatives: simd_float2 {
        return simd_float2(d2r, d2phi)
    }
    
    /// Check if ray has crossed the event horizon
    var crossedEventHorizon: Bool {
        let SagA_rs: Float = 1.269e10
        return r <= SagA_rs
    }
    
    /// Distance from black hole center
    var distanceFromCenter: Float {
        return r
    }
}

/// Camera parameters for ray generation
struct CameraUniforms {
    var position: simd_float3
    var right: simd_float3
    var up: simd_float3
    var forward: simd_float3
    var tanHalfFov: Float
    var aspect: Float
    var width: Int32
    var height: Int32
    
    init(position: simd_float3, 
         target: simd_float3, 
         up: simd_float3 = simd_float3(0, 1, 0),
         fovY: Float, 
         aspect: Float, 
         width: Int, 
         height: Int) {
        
        self.position = position
        self.forward = normalize(target - position)
        self.right = normalize(cross(self.forward, up))
        self.up = cross(self.right, self.forward)
        self.tanHalfFov = tan(fovY * 0.5)
        self.aspect = aspect
        self.width = Int32(width)
        self.height = Int32(height)
    }
}

/// Geodesic computation results
struct GeodesicResults {
    let rays: [Ray]
    let colors: [simd_float4]
    let computationTime: TimeInterval
    
    /// Number of rays that crossed the event horizon
    var blackHoleHits: Int {
        return rays.filter { $0.crossedEventHorizon }.count
    }
    
    /// Average distance of escaped rays
    var averageEscapeDistance: Float {
        let escapedRays = rays.filter { !$0.crossedEventHorizon }
        guard !escapedRays.isEmpty else { return 0.0 }
        let totalDistance = escapedRays.reduce(0.0) { $0 + $1.distanceFromCenter }
        return totalDistance / Float(escapedRays.count)
    }
}

/// Black hole parameters
struct BlackHoleParameters {
    static let sagittariusA = BlackHoleParameters(
        mass: 8.54e36,          // kg
        schwarzschildRadius: 1.269e10,  // meters
        position: simd_float3(0, 0, 0)
    )
    
    let mass: Float
    let schwarzschildRadius: Float
    let position: simd_float3
    
    init(mass: Float, schwarzschildRadius: Float, position: simd_float3) {
        self.mass = mass
        self.schwarzschildRadius = schwarzschildRadius
        self.position = position
    }
}