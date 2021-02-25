import Foundation
import Metal

class SmoothLifeMetal {

    /// The field containing the current state
    private let primaryField: MTLTexture
    private let secundairyField: MTLTexture

    var field : MTLTexture {
        return stepCount % 2 == 0 ? primaryField : secundairyField
    }

    var nextField : MTLTexture {
        return stepCount % 2 == 0 ? secundairyField : primaryField
    }

    private(set) var stepCount = 0

    private let fieldInFd: MTLTexture

    /// Also called b1 and b2
    let birthInterval: (Float, Float)

    /// Also called d1 and d2
    let deathInterval: (Float, Float)

    /// dt is the amount each step calculation should contribute to the next field.
    /// Used for smooth transitions in the time dimension
    let dt: Float

    /// Inner radius of the effective cell
    let innerRadius: Float

    /// Outer radius to the cells neightbors
    let outerRadius: Float

    /// Also called `N`
    /// The neightborhood kernel expressed in the frequency domain
    private let neightborhoodKernelInFd: MTLTexture
    private let neightborhoodKernelAppliedInFd: MTLTexture
    private let neightborhoodKernelApplied: MTLTexture

    /// Also called `M`
    /// The effectiveCell kernel expressed in the frequency domain
    private let effectiveCellKernelInFd: MTLTexture
    private let effectiveCellKernelAppliedInFd: MTLTexture
    private let effectiveCellKernelApplied: MTLTexture

    /// FFT algorithm
    private let fft: MetalFFT

    private let complexMultiplicationPipelineState: MTLComputePipelineState
    private let transitionPipelineState: MTLComputePipelineState
    private let parameterBuffer: MTLBuffer

    /// Easy accessor for the field's shape
    var shape: (height: Int, width: Int) {
        return (field.height, field.width)
    }

    init(
        shape: (height: Int, width: Int) = (64, 64),
        birthInterval: (Float, Float) = (0.254, 0.312),
        deathInterval: (Float, Float) = (0.340, 0.518),
        innerRadius: Float = 4.0,
        outerRadius: Float = 12.0,
        dt: Float = 0.1,
        field: Matrix<Float>? = nil,
        device: MTLDevice = MTLCreateSystemDefaultDevice()!
    ) {
        self.birthInterval = birthInterval
        self.deathInterval = deathInterval
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.dt = dt

        self.fft = MetalFFT(shape: shape, device: device)
        let device = self.fft.device

        self.primaryField = device.makeTexture(descriptor: SLSTextureDescriptor(shape: shape, complex: true))!
        self.secundairyField = device.makeTexture(descriptor: SLSTextureDescriptor(shape: shape, complex: true))!
        SmoothLifevDSP.randomField(radius: Int(outerRadius), shape: shape).fill(texture: self.primaryField)

        self.fieldInFd = device.makeTexture(descriptor: SLSTextureDescriptor(shape: shape, complex: true))!
        (self.effectiveCellKernelInFd, self.neightborhoodKernelInFd) = Self.kernels(shape: shape, innerRadius: innerRadius, outerRadius: outerRadius)

        self.neightborhoodKernelAppliedInFd = device.makeTexture(descriptor: SLSTextureDescriptor(shape: shape, complex: true))!
        self.neightborhoodKernelApplied = device.makeTexture(descriptor: SLSTextureDescriptor(shape: shape, complex: true))!
        self.effectiveCellKernelAppliedInFd = device.makeTexture(descriptor: SLSTextureDescriptor(shape: shape, complex: true))!
        self.effectiveCellKernelApplied = device.makeTexture(descriptor: SLSTextureDescriptor(shape: shape, complex: true))!

        let defaultLibrary = device.makeDefaultLibrary()!
        self.complexMultiplicationPipelineState = try! device.makeComputePipelineState(function: defaultLibrary.makeFunction(name: "complex_multiplication")!)
        self.transitionPipelineState = try! device.makeComputePipelineState(function: defaultLibrary.makeFunction(name: "transition")!)

        self.parameterBuffer = device.makeBuffer(length: MemoryLayout<TransitionParameters>.stride, options: [])!
    }

    /// Provides the required kernels in the frequency domain
    static func kernels(shape: (height: Int, width: Int), innerRadius: Float, outerRadius: Float) -> (MTLTexture, MTLTexture) {
        var effectiveCellKernel = SmoothLifevDSP.shiftedSmoothCircle(shape: shape, radius: innerRadius)
        var neightborhoodKernel = SmoothLifevDSP.shiftedSmoothCircle(shape: shape, radius: outerRadius) - effectiveCellKernel

        effectiveCellKernel = effectiveCellKernel / effectiveCellKernel.sum
        neightborhoodKernel = neightborhoodKernel / neightborhoodKernel.sum

        // We transform the kernels to the frequency domain
        return (effectiveCellKernel.makeMetalFftTexture(), neightborhoodKernel.makeMetalFftTexture())
    }

    /// Perform a step and update the field
    func queueStep(on commandBuffer: MTLCommandBuffer) {

        // Execute convolution in the frequency domain
        self.queueKernelApplication(on: commandBuffer)

        // Caculate the new field and update using smooth timesteps
        self.queueTransition(on: commandBuffer)

        stepCount += 1
    }

    /// Queue convolution application by multiplying in the frequency domain
    func queueKernelApplication(on commandBuffer: MTLCommandBuffer)
    {
        let _ = fft.queueCommands(on: commandBuffer, input: field, output: fieldInFd)

        self.queueComplexMultiplication(on: commandBuffer, lhs: fieldInFd, rhs: effectiveCellKernelInFd, result: effectiveCellKernelAppliedInFd)
        self.queueComplexMultiplication(on: commandBuffer, lhs: fieldInFd, rhs: neightborhoodKernelInFd, result: neightborhoodKernelAppliedInFd)

        let _ = fft.queueCommands(on: commandBuffer, .inverse, input: effectiveCellKernelAppliedInFd, output: effectiveCellKernelApplied)
        let _ = fft.queueCommands(on: commandBuffer, .inverse, input: neightborhoodKernelAppliedInFd, output: neightborhoodKernelApplied)
    }

    /// Queue transition function to be executed on the GPU
    func queueTransition(on commandBuffer: MTLCommandBuffer)
    {
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!

        computeEncoder.setComputePipelineState(transitionPipelineState)
        computeEncoder.setTexture(effectiveCellKernelApplied, index: 0)
        computeEncoder.setTexture(neightborhoodKernelApplied, index: 1)
        computeEncoder.setTexture(field, index: 2)
        computeEncoder.setTexture(nextField, index: 3)

        var params = TransitionParameters(b1: birthInterval.0, b2: birthInterval.1, d1: deathInterval.0, d2: deathInterval.1, dt: dt)
        computeEncoder.setBytes(&params, length: MemoryLayout<TransitionParameters>.stride, index: 0)

        let (threadgroupsPerGrid, threadsPerThreadgroup) = SLSThreads(for: field, and: complexMultiplicationPipelineState)

        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
    }

    /// Queue complex multiplication to be executed on the GPU
    func queueComplexMultiplication(on commandBuffer: MTLCommandBuffer, lhs: MTLTexture, rhs: MTLTexture, result: MTLTexture) {
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!

        computeEncoder.setComputePipelineState(complexMultiplicationPipelineState)
        computeEncoder.setTexture(lhs, index: 0)
        computeEncoder.setTexture(rhs, index: 1)
        computeEncoder.setTexture(result, index: 2)

        let (threadgroupsPerGrid, threadsPerThreadgroup) = SLSThreads(for: result, and: complexMultiplicationPipelineState)

        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
    }
}

/// Struct that corresponds exactly with the parameters struct in the shader
fileprivate struct TransitionParameters {
    let b1: Float
    let b2: Float
    let d1: Float
    let d2: Float
    let dt: Float
}

extension SmoothLifeMetal : Life {

    var device: MTLDevice {
        return field.device
    }

    func texture(forPresentationBy lifeRenderer: LifeRenderer) -> MTLTexture {
        return field
    }

    func lifeRenderer(_ lifeRenderer: LifeRenderer, isQueueingCommandsOnBuffer commandBuffer: MTLCommandBuffer) {
        self.queueStep(on: commandBuffer)
    }
}
