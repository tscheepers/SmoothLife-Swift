import Metal
import Foundation

/// Use this method to enable the capturing of GPU debug information
/// Only use on debug builds
func SLSCaptureGPUDebugInformation(for commandQueue: MTLCommandQueue) {
    let sharedCapturer = MTLCaptureManager.shared()
    let captureDescriptor = MTLCaptureDescriptor()
    captureDescriptor.captureObject = commandQueue
    captureDescriptor.destination = .developerTools
    try? sharedCapturer.startCapture(with: captureDescriptor)
}

func SLSThreads(for texture: MTLTexture, and computePipelineState: MTLComputePipelineState) -> (threadgroupsPerGrid: MTLSize, threadsPerThreadgroup: MTLSize) {
    let threadSize = computePipelineState.threadExecutionWidth
    let threadsPerThreadgroup = MTLSizeMake(threadSize, min(threadSize, computePipelineState.maxTotalThreadsPerThreadgroup / threadSize), 1)
    let horizontalThreadgroupCount = texture.width / threadsPerThreadgroup.width + 1
    let verticalThreadgroupCount = texture.height / threadsPerThreadgroup.height + 1
    let threadgroupsPerGrid = MTLSizeMake(horizontalThreadgroupCount, verticalThreadgroupCount, 1)
    return (threadgroupsPerGrid, threadsPerThreadgroup)
}

/// Describes a valid texture that can be used with this algorithm
func SLSTextureDescriptor(shape: (height: Int, width: Int), complex: Bool = false) -> MTLTextureDescriptor {
    let textureDescriptor = MTLTextureDescriptor()
    textureDescriptor.storageMode = .shared
    textureDescriptor.usage = [.shaderWrite, .shaderRead]
    textureDescriptor.pixelFormat = (complex ? .rg32Float : .r32Float)
    textureDescriptor.width = shape.width
    textureDescriptor.height = shape.height
    textureDescriptor.depth = 1
    return textureDescriptor
}
