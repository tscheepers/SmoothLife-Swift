import Metal
import Foundation
import UIKit
import simd

enum FFTDirection {
    case forward
    case inverse
}

class MetalFFT {

    private let computePipelineState: MTLComputePipelineState
    private let pingTexture: MTLTexture
    private let pongTexture: MTLTexture
    private let parameterBuffer: MTLBuffer

    /// Device used by the FFT
    var device : MTLDevice {
        return computePipelineState.device
    }

    /// This texture will be the input texture when no texture is provided when calling `queueCommands(on:)`
    var fallbackInputTexture: MTLTexture {
        return pingTexture
    }

    init(size: (height: Int, width: Int)) {
        let device = MTLCreateSystemDefaultDevice()!
        
        let defaultLibrary = device.makeDefaultLibrary()!
        let shader = defaultLibrary.makeFunction(name: "fft")!

        self.parameterBuffer = device.makeBuffer(length: MemoryLayout<FFTParameters>.stride, options: [])!
        self.computePipelineState = try! device.makeComputePipelineState(function: shader)
        self.pingTexture = device.makeTexture(descriptor: Self.textureDescriptor(size: size))!
        self.pongTexture = device.makeTexture(descriptor: Self.textureDescriptor(size: size))!

    }

    /// Describes a valid texture that can be used with this algorithm
    private static func textureDescriptor(size: (height: Int, width: Int)) -> MTLTextureDescriptor {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        textureDescriptor.pixelFormat = .rg32Float
        textureDescriptor.width = size.width
        textureDescriptor.height = size.height
        textureDescriptor.depth = 1
        return textureDescriptor
    }

    /// Queues the full algorithm on a MTLCommandBuffer
    func queueCommands(
        on commandBuffer: MTLCommandBuffer,
        _ direction: FFTDirection = .forward,
        input optionalInput: MTLTexture? = nil,
        output optionalOutput: MTLTexture? = nil
    ) -> MTLTexture {

        let input = optionalInput ?? pingTexture
        guard input !== pongTexture else {
            fatalError("Cannot pass the pong texture as input")
        }

        guard input.pixelFormat == .rg32Float else {
            fatalError("The pixel format of the input texture should be rg32Float")
        }

        guard input.width == pingTexture.width && input.height == pingTexture.height else {
            fatalError("Input texture dimensions do not correspond to FFT dimensions")
        }

        let (width, height) = (Float(input.width), Float(input.height))
        let (widthLog2, heightLog2) = (log2f(width), log2f(height))

        guard widthLog2 == floorf(widthLog2) && heightLog2 == floorf(heightLog2) else {
            fatalError("Width and height should be a power of 2")
        }

        let (xIters, yIters) = (Int(widthLog2), Int(heightLog2))
        let iters = xIters + yIters

        let output = optionalOutput ?? ((iters - 1) % 2 == 0 ? pongTexture : pingTexture)
        guard output !== ((iters - 1) % 2 == 0 ? pingTexture : pongTexture) else {
            fatalError("Cannot pass this internal texture as output")
        }

        guard output.pixelFormat == .rg32Float else {
            fatalError("The pixel format of the input texture should be rg32Float")
        }

        guard output.width == pingTexture.width && output.height == pingTexture.height else {
            fatalError("Output texture dimensions do not correspond to FFT dimensions")
        }

        for i in 0..<iters {

            let iterInput = (i % 2 == 0 ? pingTexture : pongTexture)
            let iterOutput = (i % 2 == 1 ? pingTexture : pongTexture)

            let forward: Bool
            switch direction {
            case .forward:
                forward = true
            case .inverse:
                forward = false
            }

            let normalization: Float
            switch (i, direction) {
            case (0, .inverse):
                normalization = 1.0 / (width * height)
            default:
                normalization = 1.0
            }

            let horizontal = i < xIters
            // Each iteration increases the iteration width with a power of two
            let power: UInt = 1 << ((horizontal ? i : (i - xIters)) + 1)

            self.queueCommand(
                commandBuffer: commandBuffer,
                input: (i == 0) ? input : iterInput,
                output: (i == iters - 1) ? output : iterOutput,
                horizontal: horizontal,
                forward: forward,
                normalization: normalization,
                dim: horizontal ? UInt(width) : UInt(height),
                power: power
            )
        }

        return output
    }

    /// Queues a single iteration of the command on a MTLCommandBuffer
    private func queueCommand(
        commandBuffer: MTLCommandBuffer,
        input: MTLTexture,
        output: MTLTexture,
        horizontal: Bool,
        forward: Bool,
        normalization: Float,
        dim: UInt,
        power: UInt
    ) {
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!

        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(output, index: 1)

        var params = FFTParameters(horizontal, forward, normalization, dim, power)
        computeEncoder.setBytes(&params, length: MemoryLayout<FFTParameters>.stride, index: 0)

        let threadSize = 16 // computePipelineState.threadExecutionWidth
        let threadsPerThreadgroup = MTLSizeMake(threadSize, threadSize, 1) // computePipelineState.maxTotalThreadsPerThreadgroup
        let horizontalThreadgroupCount = input.width / threadsPerThreadgroup.width + 1
        let verticalThreadgroupCount = output.width / threadsPerThreadgroup.height + 1
        let threadgroupsPerGrid = MTLSizeMake(horizontalThreadgroupCount, verticalThreadgroupCount, 1)

        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
    }
}

/// Struct that corresponds exactly with the parameters struct in the shader
fileprivate struct FFTParameters {

    let normalization: Float
    let horizontal: Bool
    let forward: Bool
    let dim: simd_uint1
    let power: simd_uint1

    init(
        _ horizontal: Bool,
        _ forward: Bool,
        _ normalization: Float,
        _ dim: UInt,
        _ power: UInt
    ) {
        self.horizontal = horizontal
        self.forward = forward
        self.normalization = normalization
        self.dim = simd_uint1(dim)
        self.power = simd_uint1(power)
    }
}

/// Use this method to enable the capturing of GPU debug information
/// Only use on debug builds
func SLSCaptureGPUDebugInformation(for commandQueue: MTLCommandQueue) {
    let sharedCapturer = MTLCaptureManager.shared()
    let captureDescriptor = MTLCaptureDescriptor()
    captureDescriptor.captureObject = commandQueue
    captureDescriptor.destination = .developerTools
    try? sharedCapturer.startCapture(with: captureDescriptor)
}
