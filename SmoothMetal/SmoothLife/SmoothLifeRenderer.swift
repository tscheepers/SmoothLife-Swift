import Metal
import Foundation
import UIKit
import Accelerate

// Use: https://developer.apple.com/documentation/accelerate/fast_fourier_transforms


class SmoothLifeRenderer {

    private let commandQueue: MTLCommandQueue

    private let renderPipelineState: MTLRenderPipelineState

    private let vertexBuffer: MTLBuffer

    private let primaryTexture: MTLTexture

    private let smoothLife: SmoothLife

    init(
        commandQueue: MTLCommandQueue,
        renderPipelineState: MTLRenderPipelineState,
        vertexBuffer: MTLBuffer,
        primaryTexture: MTLTexture,
        smoothLife: SmoothLife
    ) {
        self.commandQueue = commandQueue
        self.renderPipelineState = renderPipelineState
        self.vertexBuffer = vertexBuffer
        self.primaryTexture = primaryTexture
        self.smoothLife = smoothLife
    }

    func render(drawable: CAMetalDrawable) {

        smoothLife.step()
        smoothLife.field.fill(texture: primaryTexture)

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
        renderEncoder.setFragmentTexture(primaryTexture, index: 0)
        renderEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: SmoothLifeRendererFactory.rectangleVertices.count / 4,
            instanceCount: 1
        )
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

/// Creates the SmoothLifeRenderer object and auxiliary objects
class SmoothLifeRendererFactory {

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

    func createRenderer(forSmoothLife smoothLife: SmoothLife = SmoothLife()) -> SmoothLifeRenderer
    {
        let dataSize = Self.rectangleVertices.count * MemoryLayout.size(ofValue: Self.rectangleVertices[0])
        guard let vertexBuffer = device.makeBuffer(bytes: Self.rectangleVertices, length: dataSize, options: []) else {
            fatalError("Could not allocate the required memory on the GPU")
        }

        let (fragmentShader, vertexShader) = self.shaders()

        let renderPipelineState = self.createRenderPipelineState(fragmentShader: fragmentShader, vertexShader: vertexShader)

        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Unable to create a new GPU command queue")
        }

        return SmoothLifeRenderer(
            commandQueue: commandQueue,
            renderPipelineState: renderPipelineState,
            vertexBuffer: vertexBuffer,
            primaryTexture: self.createTexture(cellsWide: smoothLife.field.width, cellsHigh: smoothLife.field.height),
            smoothLife: smoothLife
        )
    }

    private func createTexture(cellsWide: Int, cellsHigh: Int) -> MTLTexture {

        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        textureDescriptor.pixelFormat = .r32Float
        textureDescriptor.width = cellsWide
        textureDescriptor.height = cellsHigh
        textureDescriptor.depth = 1

        return device.makeTexture(descriptor: textureDescriptor)!
    }

    private func shaders() -> (
        fragmentShader: MTLFunction,
        vertexShader: MTLFunction
    ) {
        guard
            let defaultLibrary = device.makeDefaultLibrary(),
            let fragmentShader = defaultLibrary.makeFunction(name: "sl_fragment_shader"),
            let vertexShader = defaultLibrary.makeFunction(name: "sl_vertex_shader")
        else {
            fatalError("Could not create GPU code library")
        }

        return (fragmentShader, vertexShader)
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
