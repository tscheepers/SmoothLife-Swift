import Metal
import Foundation
import UIKit
import simd


class FFT {

    private let commandQueue: MTLCommandQueue

    private let computePipelineState: MTLComputePipelineState

    private let inputTexture: MTLTexture
    private let pingTexture: MTLTexture
    private let pongTexture: MTLTexture
    private let outputTexture: MTLTexture

    private let parameterBuffer: MTLBuffer

    init(size: (height: Int, width: Int)) {
        let device = MTLCreateSystemDefaultDevice()!
        
        let defaultLibrary = device.makeDefaultLibrary()!
        let shader = defaultLibrary.makeFunction(name: "fft")!

        self.parameterBuffer = device.makeBuffer(length: MemoryLayout<FFTParameters>.stride, options: [])!
        self.commandQueue = device.makeCommandQueue()!
        self.computePipelineState = try! device.makeComputePipelineState(function: shader)
        self.inputTexture = device.makeTexture(descriptor: Self.textureDescriptor(size: size))!
        self.pingTexture = device.makeTexture(descriptor: Self.textureDescriptor(size: size))!
        self.pongTexture = device.makeTexture(descriptor: Self.textureDescriptor(size: size))!
        self.outputTexture = device.makeTexture(descriptor: Self.textureDescriptor(size: size))!

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

        let sharedCapturer = MTLCaptureManager.shared()

        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = commandQueue
        captureDescriptor.destination = .developerTools
        try? sharedCapturer.startCapture(with: captureDescriptor)

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
            let normalization: Float;

            switch (i, splitNormalization, direction) {
            case (0, true, _):
                normalization = 1.0 / sqrtf(width * height)
            case (0, _, .inverse):
                normalization = 1.0 / width / height
            default:
                normalization = 1.0
            }
            
            self.queueCommand(
                commandBuffer: commandBuffer,
                input: input,
                output: output,
                horizontal: horizontal,
                forward: true,
                resolution: (1.0 / width, 1.0 / height),
                normalization: normalization,
                subtransformSize: powf(2, Float(horizontal ? i : (i - xIters)) + 1.0)
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
        resolution: (Float, Float),
        normalization: Float,
        subtransformSize: Float
    ) {
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!

        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(input, index: 0)
        computeEncoder.setTexture(output, index: 1)

        var params = FFTParameters(horizontal, forward, resolution, normalization, subtransformSize)
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

enum FFTDirection {
    case forward
    case inverse
}

struct FFTParameters {
    let resolution: SIMD2<Float>
    let subtransformSize: Float
    let normalization: Float
    let horizontal: Bool
    let forward: Bool

    init(
        _ horizontal: Bool,
        _ forward: Bool,
        _ resolution: (Float, Float),
        _ normalization: Float,
        _ subtransformSize: Float
    ) {
        self.resolution = SIMD2<Float>(x: resolution.0, y: resolution.1)
        self.horizontal = horizontal
        self.subtransformSize = subtransformSize
        self.normalization = normalization
        self.forward = forward
    }
}
