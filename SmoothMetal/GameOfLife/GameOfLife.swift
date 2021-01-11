import Metal
import Foundation
import UIKit


class GameOfLife {

    private let commandQueue: MTLCommandQueue

    private let renderPipelineState: MTLRenderPipelineState

    private let computePipelineState: MTLComputePipelineState

    private let vertexBuffer: MTLBuffer

    private let primaryTexture: MTLTexture

    private let secundairyTexture: MTLTexture

    private(set) var generationTick = 0

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
        secundairyTexture: MTLTexture
    ) {
        self.commandQueue = commandQueue
        self.renderPipelineState = renderPipelineState
        self.computePipelineState = computePipelineState
        self.vertexBuffer = vertexBuffer
        self.primaryTexture = primaryTexture
        self.secundairyTexture = secundairyTexture
    }

    func restart(random: Bool) {
        generationTick = 0
        let (width, height) = (currentTexture.width, currentTexture.height)

        var seed = [UInt8](repeating: 0, count: width * height)
        if random {
            let numberOfCells = width * height
            let numberOfLiveCells = Int(pow(Double(numberOfCells), 0.8))
            for _ in (0..<numberOfLiveCells) {
                let r = (0..<numberOfCells).randomElement()!
                seed[r] = 1
            }
        }

        currentTexture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: seed,
            bytesPerRow: width * MemoryLayout<UInt8>.stride
        )
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
            vertexCount: GameOfLifeFactory.rectangleVertices.count / 4,
            instanceCount: 1
        )
        renderEncoder.endEncoding()

        guard
          let computeEncoder = commandBuffer.makeComputeCommandEncoder()
          else { return }

        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(currentTexture, index: 0)
        computeEncoder.setTexture(nextTexture, index: 1)

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

/// Creates the GameOfLife object and auxiliary objects
class GameOfLifeFactory {

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

    func create(cellsWide: Int = 100, cellsHigh: Int = 100) -> GameOfLife
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

        return GameOfLife(
            commandQueue: commandQueue,
            renderPipelineState: renderPipelineState,
            computePipelineState: computePipelineState,
            vertexBuffer: vertexBuffer,
            primaryTexture: self.createTextures(cellsWide: cellsWide, cellsHigh: cellsHigh),
            secundairyTexture: self.createTextures(cellsWide: cellsWide, cellsHigh: cellsHigh)
        )
    }

    private func createTextures(cellsWide: Int, cellsHigh: Int) -> MTLTexture {

        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        textureDescriptor.pixelFormat = .r8Uint
        textureDescriptor.width = cellsWide
        textureDescriptor.height = cellsHigh
        textureDescriptor.depth = 1

        return device.makeTexture(descriptor: textureDescriptor)!
    }


    private func shaders() -> (
        fragmentShader: MTLFunction,
        vertexShader: MTLFunction,
        computeShader: MTLFunction
    ) {
        guard
            let defaultLibrary = device.makeDefaultLibrary(),
            let fragmentShader = defaultLibrary.makeFunction(name: "gol_fragment_shader"),
            let vertexShader = defaultLibrary.makeFunction(name: "gol_vertex_shader"),
            let computeShader = defaultLibrary.makeFunction(name: "gol_compute_shader")
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
