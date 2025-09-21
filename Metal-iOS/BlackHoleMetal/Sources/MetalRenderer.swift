//
//  MetalRenderer.swift
//  BlackHoleMetal
//
//  Metal rendering pipeline for black hole geodesic computation
//

import Foundation
import Metal
import MetalKit
import simd

class MetalRenderer: NSObject, ObservableObject {
    
    // MARK: - Properties
    
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var computePipelineState: MTLComputePipelineState
    
    private var rayBuffer: MTLBuffer
    private var colorBuffer: MTLBuffer
    private var cameraBuffer: MTLBuffer
    
    @Published var rays: [Ray] = []
    @Published var colors: [simd_float4] = []
    @Published var isComputing = false
    @Published var lastComputationTime: TimeInterval = 0.0
    
    private let imageWidth: Int
    private let imageHeight: Int
    private let totalPixels: Int
    
    // MARK: - Initialization
    
    init(width: Int = 800, height: Int = 600) throws {
        self.imageWidth = width
        self.imageHeight = height
        self.totalPixels = width * height
        
        // Get Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalError.deviceNotFound
        }
        self.device = device
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue
        
        // Create buffers
        let rayBufferLength = totalPixels * MemoryLayout<Ray>.stride
        guard let rayBuffer = device.makeBuffer(length: rayBufferLength, 
                                               options: .storageModeShared) else {
            throw MetalError.bufferCreationFailed
        }
        self.rayBuffer = rayBuffer
        
        let colorBufferLength = totalPixels * MemoryLayout<simd_float4>.stride
        guard let colorBuffer = device.makeBuffer(length: colorBufferLength,
                                                 options: .storageModeShared) else {
            throw MetalError.bufferCreationFailed
        }
        self.colorBuffer = colorBuffer
        
        let cameraBufferLength = MemoryLayout<CameraUniforms>.stride
        guard let cameraBuffer = device.makeBuffer(length: cameraBufferLength,
                                                  options: .storageModeShared) else {
            throw MetalError.bufferCreationFailed
        }
        self.cameraBuffer = cameraBuffer
        
        // Load shader library
        guard let library = device.makeDefaultLibrary() else {
            throw MetalError.libraryCreationFailed
        }
        
        // Get compute function
        guard let computeFunction = library.makeFunction(name: "geodesicRayTrace") else {
            throw MetalError.functionNotFound
        }
        
        // Create compute pipeline state
        do {
            self.computePipelineState = try device.makeComputePipelineState(function: computeFunction)
        } catch {
            throw MetalError.pipelineStateCreationFailed
        }
        
        super.init()
        
        // Initialize with default values
        self.rays = Array(repeating: Ray(position: simd_float3(0, 0, 0), 
                                        direction: simd_float3(0, 0, 1)), 
                         count: totalPixels)
        self.colors = Array(repeating: simd_float4(0, 0, 0, 1), count: totalPixels)
    }
    
    // MARK: - Public Methods
    
    /// Compute geodesics for given camera parameters
    func computeGeodesics(camera: CameraUniforms) async throws -> GeodesicResults {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await MainActor.run {
            self.isComputing = true
        }
        
        defer {
            Task { @MainActor in
                self.isComputing = false
            }
        }
        
        // Update camera buffer
        let cameraPointer = cameraBuffer.contents().bindMemory(to: CameraUniforms.self, capacity: 1)
        cameraPointer.pointee = camera
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalError.commandBufferCreationFailed
        }
        
        // Create compute encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.computeEncoderCreationFailed
        }
        
        // Set pipeline state
        computeEncoder.setComputePipelineState(computePipelineState)
        
        // Set buffers
        computeEncoder.setBuffer(cameraBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(rayBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(colorBuffer, offset: 0, index: 2)
        
        // Calculate threadgroup size
        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadsPerGrid = MTLSize(width: imageWidth, height: imageHeight, depth: 1)
        
        // Dispatch compute kernel
        computeEncoder.dispatchThreads(threadsPerGrid, 
                                      threadsPerThreadgroup: threadsPerThreadgroup)
        
        // End encoding
        computeEncoder.endEncoding()
        
        // Commit and wait
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Check for errors
        if commandBuffer.status == .error {
            throw MetalError.computationFailed
        }
        
        // Read results back from GPU
        let rayPointer = rayBuffer.contents().bindMemory(to: Ray.self, capacity: totalPixels)
        let colorPointer = colorBuffer.contents().bindMemory(to: simd_float4.self, capacity: totalPixels)
        
        let newRays = Array(UnsafeBufferPointer(start: rayPointer, count: totalPixels))
        let newColors = Array(UnsafeBufferPointer(start: colorPointer, count: totalPixels))
        
        let computationTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Update published properties on main thread
        await MainActor.run {
            self.rays = newRays
            self.colors = newColors
            self.lastComputationTime = computationTime
        }
        
        return GeodesicResults(rays: newRays, colors: newColors, computationTime: computationTime)
    }
    
    /// Get ray at specific pixel coordinates
    func ray(at x: Int, y: Int) -> Ray? {
        guard x >= 0 && x < imageWidth && y >= 0 && y < imageHeight else {
            return nil
        }
        let index = y * imageWidth + x
        return rays[index]
    }
    
    /// Get color at specific pixel coordinates
    func color(at x: Int, y: Int) -> simd_float4? {
        guard x >= 0 && x < imageWidth && y >= 0 && y < imageHeight else {
            return nil
        }
        let index = y * imageWidth + x
        return colors[index]
    }
    
    /// Create default camera looking at black hole
    func defaultCamera() -> CameraUniforms {
        let position = simd_float3(6.34194e10, 0, 0)  // Far from black hole
        let target = simd_float3(0, 0, 0)             // Look at center
        let fovY: Float = 60.0 * .pi / 180.0          // 60 degrees in radians
        let aspect = Float(imageWidth) / Float(imageHeight)
        
        return CameraUniforms(position: position, 
                             target: target, 
                             fovY: fovY, 
                             aspect: aspect, 
                             width: imageWidth, 
                             height: imageHeight)
    }
}

// MARK: - Error Types

enum MetalError: Error, LocalizedError {
    case deviceNotFound
    case commandQueueCreationFailed
    case bufferCreationFailed
    case libraryCreationFailed
    case functionNotFound
    case pipelineStateCreationFailed
    case commandBufferCreationFailed
    case computeEncoderCreationFailed
    case computationFailed
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Metal device not found"
        case .commandQueueCreationFailed:
            return "Failed to create Metal command queue"
        case .bufferCreationFailed:
            return "Failed to create Metal buffer"
        case .libraryCreationFailed:
            return "Failed to create Metal shader library"
        case .functionNotFound:
            return "Compute function not found in shader library"
        case .pipelineStateCreationFailed:
            return "Failed to create compute pipeline state"
        case .commandBufferCreationFailed:
            return "Failed to create command buffer"
        case .computeEncoderCreationFailed:
            return "Failed to create compute encoder"
        case .computationFailed:
            return "Metal computation failed"
        }
    }
}

// MARK: - Extensions

extension MetalRenderer {
    /// Get statistics about the current computation
    var statistics: String {
        let blackHoleHits = rays.filter { $0.crossedEventHorizon }.count
        let escapedRays = totalPixels - blackHoleHits
        let hitPercentage = Double(blackHoleHits) / Double(totalPixels) * 100.0
        
        return """
        Total Rays: \(totalPixels)
        Black Hole Hits: \(blackHoleHits) (\(String(format: "%.1f", hitPercentage))%)
        Escaped Rays: \(escapedRays)
        Computation Time: \(String(format: "%.3f", lastComputationTime))s
        """
    }
}