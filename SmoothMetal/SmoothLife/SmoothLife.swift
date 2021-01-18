import Metal
import Foundation
import UIKit
import Accelerate

// Use: https://developer.apple.com/documentation/accelerate/fast_fourier_transforms


class SmoothLife {

    private let commandQueue: MTLCommandQueue

    private let renderPipelineState: MTLRenderPipelineState

    private let computePipelineState: MTLComputePipelineState

    private let vertexBuffer: MTLBuffer

    /// Also called the field
    private let primaryTexture: MTLTexture
    private let secundairyTexture: MTLTexture

    /// Also called `N`
    private let neightborhoodTexture: MTLTexture
    /// The neightborhood kernel expressed in the frequency domain
    private let neightborhoodKernel: Matrix<ComplexDouble>

    /// Also called `M`
    private let effectiveCellTexture: MTLTexture
    /// The effectiveCell kernel expressed in the frequency domain
    private let effectiveCellKernel: Matrix<ComplexDouble>

    private(set) var generationTick = 0

    private let innerRadius: Double
    private let outerRadius: Double

    var currentTexture : MTLTexture {
        return generationTick % 2 == 0 ? primaryTexture : secundairyTexture
    }

    var nextTexture : MTLTexture {
        return generationTick % 2 == 0 ? secundairyTexture : primaryTexture
    }

    init(
        commandQueue: MTLCommandQueue,
        renderPipelineState: MTLRenderPipelineState,
        computePipelineState: MTLComputePipelineState,
        vertexBuffer: MTLBuffer,
        primaryTexture: MTLTexture,
        secundairyTexture: MTLTexture,
        neightborhoodTexture: MTLTexture,
        effectiveCellTexture: MTLTexture,
        neightborhoodKernel: Matrix<ComplexDouble>,
        effectiveCellKernel: Matrix<ComplexDouble>,
        innerRadius: Double,
        outerRadius: Double
    ) {
        self.commandQueue = commandQueue
        self.renderPipelineState = renderPipelineState
        self.computePipelineState = computePipelineState
        self.vertexBuffer = vertexBuffer
        self.primaryTexture = primaryTexture
        self.secundairyTexture = secundairyTexture
        self.neightborhoodTexture = neightborhoodTexture
        self.effectiveCellTexture = effectiveCellTexture
        self.neightborhoodKernel = neightborhoodKernel
        self.effectiveCellKernel = effectiveCellKernel
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
    }

    func restart() {
        generationTick = 0
        let shape = (height: currentTexture.height, width: currentTexture.width)
        var seed = Matrix<Double>.zeros(shape: shape)

        let liveCells: Int = seed.n / Int(pow(innerRadius * 2, 2))
        for _ in 0..<liveCells {
            let intRadius = Int(innerRadius)
            let r = (0..<seed.height - intRadius).randomElement()!
            let c = (0..<seed.width - intRadius).randomElement()!

            for i in r..<r+intRadius {
                for j in c..<c+intRadius {
                    seed[i,j] = 1.0
                }
            }
        }

        seed.fill(texture: currentTexture)
    }

    func render(drawable: CAMetalDrawable) {

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(currentTexture, index: 0)
        renderEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: SmoothLifeFactory.rectangleVertices.count / 4,
            instanceCount: 1
        )
        renderEncoder.endEncoding()

        guard
          let computeEncoder = commandBuffer.makeComputeCommandEncoder()
          else { return }


        let field = Matrix<Float>.copy(fromTexture: currentTexture).map({ Double($0) })
        let fieldInFd = field.fft()
        let neightborhoodForTexture = (fieldInFd * self.neightborhoodKernel).fft(.inverse)
        let effectiveCellForTexture = (fieldInFd * self.effectiveCellKernel).fft(.inverse)

        neightborhoodForTexture.real.fill(texture: neightborhoodTexture)
        effectiveCellForTexture.real.fill(texture: effectiveCellTexture)

        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(neightborhoodTexture, index: 0)
        computeEncoder.setTexture(effectiveCellTexture, index: 1)
        computeEncoder.setTexture(currentTexture, index: 2)
        computeEncoder.setTexture(nextTexture, index: 3)

        let threadWidth = computePipelineState.threadExecutionWidth
        let threadHeight = computePipelineState.maxTotalThreadsPerThreadgroup / threadWidth
        let threadsPerThreadgroup = MTLSizeMake(threadWidth, threadHeight, 1)
        let threadsPerGrid = MTLSizeMake(currentTexture.width, currentTexture.height, 1)

        computeEncoder.dispatchThreadgroups(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        generationTick += 1
    }
}

/// Creates the SmoothLife object and auxiliary objects
class SmoothLifeFactory {

    // Create simple rectangle from two triangles to draw
    // the texture onto
    static let rectangleVertices: [Float] = [
        -1.0, -1.0, 0.0, 1.0,
         1.0, -1.0, 0.0, 1.0,
        -1.0,  1.0, 0.0, 1.0,
        -1.0,  1.0, 0.0, 1.0,
         1.0, -1.0, 0.0, 1.0,
         1.0,  1.0, 0.0, 1.0
    ]

    private let device: MTLDevice

    init(device: MTLDevice? = nil) {
        guard let device = device ?? MTLCreateSystemDefaultDevice() else {
            fatalError("Metal GPU device reference could not be created.")
        }

        self.device = device
    }

    func create(cellsWide: Int = 100, cellsHigh: Int = 100, innerRadius: Double = 12.0, outerRadius: Double = 4.0) -> SmoothLife
    {
        let dataSize = Self.rectangleVertices.count * MemoryLayout.size(ofValue: Self.rectangleVertices[0])
        guard let vertexBuffer = device.makeBuffer(bytes: Self.rectangleVertices, length: dataSize, options: []) else {
            fatalError("Could not allocate the required memory on the GPU")
        }

        let (fragmentShader, vertexShader, computeShader) = self.shaders()

        let renderPipelineState = self.createRenderPipelineState(fragmentShader: fragmentShader, vertexShader: vertexShader)
        let computePipelineState = try! device.makeComputePipelineState(function: computeShader)

        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Unable to create a new GPU command queue")
        }

        let (effectiveCellKernel, neightborhoodKernel) = self.kernels(
            cellsWide: cellsWide,
            cellsHigh: cellsHigh,
            innerRadius: innerRadius,
            outerRadius: outerRadius
        )

        return SmoothLife(
            commandQueue: commandQueue,
            renderPipelineState: renderPipelineState,
            computePipelineState: computePipelineState,
            vertexBuffer: vertexBuffer,
            primaryTexture: self.createTexture(cellsWide: cellsWide, cellsHigh: cellsHigh),
            secundairyTexture: self.createTexture(cellsWide: cellsWide, cellsHigh: cellsHigh),
            neightborhoodTexture: self.createTexture(cellsWide: cellsWide, cellsHigh: cellsHigh),
            effectiveCellTexture: self.createTexture(cellsWide: cellsWide, cellsHigh: cellsHigh),
            neightborhoodKernel: neightborhoodKernel,
            effectiveCellKernel: effectiveCellKernel,
            innerRadius: innerRadius,
            outerRadius: outerRadius
        )
    }

    /// Provides the required kernels in the frequency domain
    private func kernels(cellsWide: Int, cellsHigh: Int, innerRadius: Double, outerRadius: Double) -> (Matrix<ComplexDouble>, Matrix<ComplexDouble>) {
        var effectiveCellKernel = self.shiftedSmoothCircle(cellsWide: cellsWide, cellsHigh: cellsHigh, radius: innerRadius)
        var neightborhoodKernel = self.shiftedSmoothCircle(cellsWide: cellsWide, cellsHigh: cellsHigh, radius: outerRadius) - effectiveCellKernel

        effectiveCellKernel = effectiveCellKernel / effectiveCellKernel.sum
        neightborhoodKernel = neightborhoodKernel / neightborhoodKernel.sum

        // We transform the kernels to the frequency domain
        return (effectiveCellKernel.fft(), neightborhoodKernel.fft())
    }

    private func createTexture(cellsWide: Int, cellsHigh: Int) -> MTLTexture {

        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2D
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        textureDescriptor.pixelFormat = .r32Float
        textureDescriptor.width = cellsWide
        textureDescriptor.height = cellsHigh
        textureDescriptor.depth = 1

//        let buffer = device.makeBuffer(length: cellsHigh * cellsWide * 4, options: .storageModeShared)!
//
//        return buffer.makeTexture(descriptor: textureDescriptor, offset: 0, bytesPerRow: cellsWide * MemoryLayout<Double>.stride)!
        return device.makeTexture(descriptor: textureDescriptor)!
    }

    /// Creates a shifted smooth cricle with extremes at the edges
    func shiftedSmoothCircle(cellsWide: Int, cellsHigh: Int, radius: Double = 12.0) -> Matrix<Double> {

        let (y, x) = (Double(cellsWide), Double(cellsHigh))
        let (yy, xx) = Matrix<Double>.meshGrid(shape: (height: cellsHigh, width: cellsWide))

        let radii = sqrt(pow(xx - x/2, power: 2) + pow(yy - y/2, power: 2))
        let logistic = 1 / (1 + exp(log2(min(y, x)) * (radii - radius)))

        return logistic
            .roll(rows: cellsHigh/2)
            .roll(cols: cellsWide/2)
    }


    private func shaders() -> (
        fragmentShader: MTLFunction,
        vertexShader: MTLFunction,
        computeShader: MTLFunction
    ) {
        guard
            let defaultLibrary = device.makeDefaultLibrary(),
            let fragmentShader = defaultLibrary.makeFunction(name: "sl_fragment_shader"),
            let vertexShader = defaultLibrary.makeFunction(name: "sl_vertex_shader"),
            let computeShader = defaultLibrary.makeFunction(name: "sl_compute_shader")
        else {
            fatalError("Could not create GPU code library")
        }

        return (fragmentShader, vertexShader, computeShader)
    }

    private func createRenderPipelineState(fragmentShader: MTLFunction, vertexShader: MTLFunction) -> MTLRenderPipelineState
    {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexShader
        descriptor.fragmentFunction = fragmentShader
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        return try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    func createMetalLayer(frame: CGRect) -> CAMetalLayer {
        let metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.contentsScale = UIScreen.main.scale
        metalLayer.frame = frame
        return metalLayer
    }

}
