import Metal
import Foundation
import UIKit
import Accelerate

protocol Life {
    var device: MTLDevice { get }
    func texture(forPresentationBy lifeRenderer: LifeRenderer) -> MTLTexture
    func lifeRenderer(_ lifeRenderer: LifeRenderer, isQueueingCommandsOnBuffer commandBuffer: MTLCommandBuffer)
}


class LifeRenderer {

    private let commandQueue: MTLCommandQueue

    private let renderPipelineState: MTLRenderPipelineState

    private let vertexBuffer: MTLBuffer

    private let life: Life

    var device: MTLDevice {
        return life.device
    }

    convenience init(life: Life) {

        let device = life.device

        let dataSize = Self.rectangleVertices.count * MemoryLayout.size(ofValue: Self.rectangleVertices[0])
        guard let vertexBuffer = device.makeBuffer(bytes: Self.rectangleVertices, length: dataSize, options: []) else {
            fatalError("Could not allocate the required memory on the GPU")
        }

        let renderPipelineState = Self.createRenderPipelineState(for:device)

        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Unable to create a new GPU command queue")
        }

        self.init(
            commandQueue: commandQueue,
            renderPipelineState: renderPipelineState,
            vertexBuffer: vertexBuffer,
            life: life
        )
    }

    init(
        commandQueue: MTLCommandQueue,
        renderPipelineState: MTLRenderPipelineState,
        vertexBuffer: MTLBuffer,
        life: Life
    ) {
        self.commandQueue = commandQueue
        self.renderPipelineState = renderPipelineState
        self.vertexBuffer = vertexBuffer
        self.life = life
    }

    func render(drawable: CAMetalDrawable) {

        let texture = life.texture(forPresentationBy: self)

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
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: Self.rectangleVertices.count / 4,
            instanceCount: 1
        )
        renderEncoder.endEncoding()

        life.lifeRenderer(self, isQueueingCommandsOnBuffer: commandBuffer)

        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    // MARK: -

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

    static private func createRenderPipelineState(for device: MTLDevice) -> MTLRenderPipelineState
    {
        let (fragmentShader, vertexShader) = Self.shaders(for: device)

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexShader
        descriptor.fragmentFunction = fragmentShader
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        return try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    static private func shaders(for device: MTLDevice) -> (
        fragmentShader: MTLFunction,
        vertexShader: MTLFunction
    ) {
        guard
            let defaultLibrary = device.makeDefaultLibrary(),
            let fragmentShader = defaultLibrary.makeFunction(name: "fragment_shader"),
            let vertexShader = defaultLibrary.makeFunction(name: "vertex_shader")
        else {
            fatalError("Could not create GPU code library")
        }

        return (fragmentShader, vertexShader)
    }

    func createMetalLayer(frame: CGRect) -> CAMetalLayer {
        let metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.contentsScale = UIScreen.main.scale
        metalLayer.frame = frame

        // Check for square texture, make sure it is not streched
        let texture = self.life.texture(forPresentationBy: self)
        if texture.width == texture.height {
            metalLayer.frame = CGRect(x: -(frame.height - frame.width) / 2, y: 0, width: frame.height, height: frame.height)
        }

        return metalLayer
    }
}
