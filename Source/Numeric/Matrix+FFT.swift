import Foundation
import Accelerate
import Metal

/// Implementation of both Metal and vDSP FFT added to the Matrix class
enum FFTImplementation {
    case vDSP
    case metal
}


// MARK: - Float
extension Matrix where T == Float {

    func fft(_ direction: FFTDirection = .forward, implementation: FFTImplementation = .vDSP) -> Matrix<Complex<Float>> {
        switch implementation {
        case .vDSP:
            return vdspFft(direction)
        case .metal:
            return metalFft(direction)
        }
    }

    func metalFft(_ direction: FFTDirection = .forward) -> Matrix<Complex<Float>> {
        return self.complex.metalFft(direction)
    }

    func vdspFft(_ direction: FFTDirection = .forward, reuseSetup setup: FFTSetup? = nil) -> Matrix<Complex<Float>> {
        return self.complex.vdspFft(direction, reuseSetup: setup)
    }
}

// MARK: - Complex
extension Matrix where T == Complex<Float> {

    func fft(_ direction: FFTDirection = .forward, implementation: FFTImplementation = .vDSP) -> Matrix<T> {
        switch implementation {
        case .vDSP:
            return vdspFft(direction)
        case .metal:
            return metalFft(direction)
        }
    }

    func metalFft(_ direction : FFTDirection = .forward) -> Matrix<T> {
        let fftSetup = MetalFFT(size: self.shape)
        return fftSetup.perform(on: self, direction)
    }

    func vdspFft(_ direction: FFTDirection = .forward, reuseSetup setup: FFTSetup? = nil) -> Matrix<T> {

        let reals = UnsafeMutableBufferPointer<Float>.allocate(capacity: n)
        let imags = UnsafeMutableBufferPointer<Float>.allocate(capacity: n)

        _ = reals.initialize(from: flat.map({ $0.real }))
        _ = imags.initialize(from: flat.map({ $0.imaginary }))

        var complexBuffer = DSPSplitComplex(realp: reals.baseAddress!, imagp: imags.baseAddress!)

        // If no reusable fft setup is specified we'll create a one-off
        let fftSetup = setup ?? self.createVdspFftSetup()
        let log2Width = UInt(log2f(Float(width)))
        let log2Height = UInt(log2f(Float(height)))

        vDSP_fft2d_zip(fftSetup, &complexBuffer, 1, 0, log2Width, log2Height, direction.vdspFftDirection)

        let flat = zip(reals, imags).map({ (real, imag) -> T in
            switch (direction) {
            case .inverse:
                return Complex<Float>(real / Float(n), imag / Float(n))
            default:
                return Complex<Float>(real, imag)
            }
       })

        defer {
            imags.deallocate()
            reals.deallocate()

            if setup == nil {
                vDSP_destroy_fftsetup(fftSetup)
            }
        }

        return Self(shape: shape, flat: flat)
    }
}

// MARK: - Extension to MetalFFT
extension MetalFFT {
    func perform(on input: Matrix<Complex<Float>>, _ direction: FFTDirection = .forward) -> Matrix<Complex<Float>> {

        let commandQueue = device.makeCommandQueue()!

        #if DEBUG
        SLSCaptureGPUDebugInformation(for: commandQueue)
        #endif

        let commandBuffer = commandQueue.makeCommandBuffer()!
        input.fill(texture: fallbackInputTexture)

        let resultTexture = queueCommands(on: commandBuffer, direction)

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return Matrix<Complex<Float>>.copy(fromTexture: resultTexture)
    }
}

extension FFTDirection {
    var vdspFftDirection: Int32 {
        return vdspDirection.fftDirection
    }

    var vdspDirection: vDSP.FourierTransformDirection {
        switch self {
        case .forward:
            return .forward
        case .inverse:
            return .inverse
        }
    }
}

// MARK: - Extension for vDSP
extension Matrix {
    /// Create a reference to an fftSetup object
    /// You are resonsible for calling `vDSP_destroy_fftsetup()` when it is no longer required
    func createVdspFftSetup() -> FFTSetup {
        let log2Size = UInt(log2(Float(n)))

        guard let fftSetup = vDSP_create_fftsetup(log2Size, FFTRadix(kFFTRadix2)) else {
            fatalError("Could not initialize FFT Setup")
        }

        return fftSetup
    }
}
