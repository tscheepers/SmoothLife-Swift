import Metal
import Foundation
import UIKit
import simd


class FFT {

    private let commandQueue: MTLCommandQueue

    private let computePipelineState: MTLComputePipelineState

    private let pingTexture: MTLTexture
    private let pongTexture: MTLTexture

    private let parameterBuffer: MTLBuffer

    init(size: (height: Int, width: Int)) {
        let device = MTLCreateSystemDefaultDevice()!
        
        let defaultLibrary = device.makeDefaultLibrary()!
        let shader = defaultLibrary.makeFunction(name: "fft")!

        self.parameterBuffer = device.makeBuffer(length: MemoryLayout<FFTParameters>.stride, options: [])!
        self.commandQueue = device.makeCommandQueue()!
        self.computePipelineState = try! device.makeComputePipelineState(function: shader)
        self.pingTexture = device.makeTexture(descriptor: Self.textureDescriptor(size: size))!
        self.pongTexture = device.makeTexture(descriptor: Self.textureDescriptor(size: size))!

    }

    static func textureDescriptor(size: (height: Int, width: Int)) -> MTLTextureDescriptor {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        textureDescriptor.pixelFormat = .rg32Float
        textureDescriptor.width = size.width
        textureDescriptor.height = size.height
        textureDescriptor.depth = 1
        return textureDescriptor
    }

    func execute(input: Matrix<Complex<Float>>, direction: FFTDirection = .forward, splitNormalization: Bool = false) -> Matrix<Complex<Float>> {

        self.startRecordingForDebugger()

        let commandBuffer = commandQueue.makeCommandBuffer()!

        input.fill(texture: pingTexture)

        let (width, height) = (Float(input.shape.width), Float(input.shape.height))

        let xIters = Int(log2f(width))
        let yIters = Int(log2f(height))
        let iters = xIters + yIters

        for i in 0..<iters {

            let input = (i % 2 == 0 ? pingTexture : pongTexture)
            let output = (i % 2 == 1 ? pingTexture : pongTexture)

            let horizontal = i < xIters
            let normalization: Float
            let forward: Bool

            switch direction {
            case .forward:
                forward = true
            case .inverse:
                forward = false
            }

            switch (i, splitNormalization, direction) {
            case (0, true, _):
                normalization = 1.0 / sqrtf(width * height)
            case (0, _, .inverse):
                normalization = 1.0 / (width * height)
            default:
                normalization = 1.0
            }

            // Each iteration increases the iteration width with a power of two
            let power: UInt = 1 << ((horizontal ? i : (i - xIters)) + 1)
            
            self.queueCommand(
                commandBuffer: commandBuffer,
                input: input,
                output: output,
                horizontal: horizontal,
                forward: forward,
                normalization: normalization,
                dim: horizontal ? UInt(width) : UInt(height),
                power: power
            )

        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return Matrix<Complex<Float>>.copy(fromTexture: ((iters - 1) % 2 == 0 ? pongTexture : pingTexture))
    }

    func queueCommand(
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

    func startRecordingForDebugger() {
        let sharedCapturer = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = commandQueue
        captureDescriptor.destination = .developerTools
        try? sharedCapturer.startCapture(with: captureDescriptor)
    }
}

enum FFTDirection {
    case forward
    case inverse
}

struct FFTParameters {

    let normalization: Float
    let horizontal: Bool
    let forward: Bool

    let dim: simd_uint1

    /// Will be `2^i` where `i` is the iteration
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
