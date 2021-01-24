import Metal
import Foundation
import UIKit


class GameOfLife {

    private let computePipelineState: MTLComputePipelineState

    private let primaryTexture: MTLTexture

    private let secundairyTexture: MTLTexture

    private(set) var generationTick = 0

    var currentTexture : MTLTexture {
        return generationTick % 2 == 0 ? primaryTexture : secundairyTexture
    }

    var nextTexture : MTLTexture {
        return generationTick % 2 == 0 ? secundairyTexture : primaryTexture
    }

    convenience init(shape: (height: Int, width: Int) = (64, 64), device: MTLDevice = MTLCreateSystemDefaultDevice()!) {
        
        let defaultLibrary = device.makeDefaultLibrary()!
        let shader = defaultLibrary.makeFunction(name: "gol_compute_shader")!

        self.init(
            computePipelineState: try! device.makeComputePipelineState(function: shader),
            primaryTexture: device.makeTexture(descriptor: SLSTextureDescriptor(shape: shape))!,
            secundairyTexture: device.makeTexture(descriptor: SLSTextureDescriptor(shape: shape))!
        )
    }

    init(
        computePipelineState: MTLComputePipelineState,
        primaryTexture: MTLTexture,
        secundairyTexture: MTLTexture
    ) {
        self.computePipelineState = computePipelineState
        self.primaryTexture = primaryTexture
        self.secundairyTexture = secundairyTexture

        restart()
    }

    func restart() {

        generationTick = 0

        let (height, width) = (currentTexture.height, currentTexture.width)

        var seed = [Float](repeating: 0, count: width * height)
        let numberOfCells = width * height
        let numberOfLiveCells = Int(pow(Double(numberOfCells), 0.8))
        for _ in (0..<numberOfLiveCells) {
            let r = (0..<numberOfCells).randomElement()!
            seed[r] = 1.0
        }

        currentTexture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: seed,
            bytesPerRow: width * MemoryLayout<Float>.stride
        )
    }

    func queueCommands(on commandBuffer: MTLCommandBuffer) {

        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!

        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(currentTexture, index: 0)
        computeEncoder.setTexture(nextTexture, index: 1)

        let (threadgroupsPerGrid, threadsPerThreadgroup) = SLSThreads(for: nextTexture, and: computePipelineState)

        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()

        generationTick += 1
    }
}

extension GameOfLife : Life {

    var device: MTLDevice {
        return currentTexture.device
    }

    func texture(forPresentationBy lifeRenderer: LifeRenderer) -> MTLTexture {
        return currentTexture
    }

    func lifeRenderer(_ lifeRenderer: LifeRenderer, isQueueingCommandsOnBuffer commandBuffer: MTLCommandBuffer) {
        queueCommands(on: commandBuffer)
    }
}
