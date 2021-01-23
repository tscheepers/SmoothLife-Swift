import Foundation
import Accelerate
import Metal

/// Implementation of both Metal and vDSP FFT added to the Matrix class
enum FFTImplementation {
    case vDSP
    case metal
}

// MARK: - Double
extension Matrix where T == Double {

    func fft(_ direction: FFTDirection = .forward, implementation: FFTImplementation = .vDSP) -> Matrix<Complex<Double>> {
        switch implementation {
        case .vDSP:
            return vdspFft(direction)
        case .metal:
            return metalFft(direction)
        }
    }

    func metalFft(_ direction: FFTDirection = .forward) -> Matrix<Complex<Double>> {
        return self
            .map({ Complex(Float($0), 0) })
            .metalFft(direction)
            .map({ Complex<Double>(Double($0.real), Double($0.imaginary)) })
    }

    func vdspFft(_ direction: FFTDirection = .forward, reuseSetup setup: FFTSetupD? = nil) -> Matrix<Complex<Double>> {
        return self.complex.vdspFft(direction, reuseSetup: setup)
    }
}


// MARK: - Complex
extension Matrix where T == Complex<Double> {

    func fft(_ direction: FFTDirection = .forward, implementation: FFTImplementation = .vDSP) -> Matrix<Complex<Double>> {
        switch implementation {
        case .vDSP:
            return vdspFft(direction)
        case .metal:
            return metalFft(direction)
        }
    }

    func metalFft(_ direction: FFTDirection = .forward) -> Matrix<Complex<Double>> {
        return self
            .map({ Complex(Float($0.real), Float($0.imaginary)) })
            .metalFft(direction)
            .map({ Complex<Double>(Double($0.real), Double($0.imaginary)) })
    }

    // MARK: Fast vDSP methods specific to Complex<Double>

    func vdspFft(_ direction: FFTDirection = .forward, reuseSetup setup: FFTSetupD? = nil) -> Matrix<Complex<Double>> {

        let reals = UnsafeMutableBufferPointer<Double>.allocate(capacity: n)
        let imags =  UnsafeMutableBufferPointer<Double>.allocate(capacity: n)

        _ = reals.initialize(from: flat.map({ $0.real }))
        _ = imags.initialize(from: flat.map({ $0.imaginary }))

        var complexBuffer = DSPDoubleSplitComplex(realp: reals.baseAddress!, imagp: imags.baseAddress!)

        // If no reusable fft setup is specified we'll create a one-off
        let fftSetup = setup ?? self.createVdspFftSetup()
        let log2Width = UInt(log2(Double(width)))
        let log2Height = UInt(log2(Double(height)))

        vDSP_fft2d_zipD(fftSetup, &complexBuffer, 1, 0, log2Width, log2Height, direction.vdspFftDirection)

        let flat = zip(reals, imags).map({ (real, imag) -> Complex<Double> in
            switch (direction) {
            case .inverse:
                return Complex<Double>(real / Double(n), imag / Double(n))
            default:
                return Complex<Double>(real, imag)
            }
       })

        defer {
            imags.deallocate()
            reals.deallocate()

            if setup == nil {
                vDSP_destroy_fftsetupD(fftSetup)
            }
        }

        return Self(shape: shape, flat: flat)
    }
}

// MARK: - Complex Float
extension Matrix where T == Complex<Float> {

    func metalFft(_ direction : FFTDirection = .forward) -> Matrix<Complex<Float>> {
        let fftSetup = MetalFFT(size: self.shape)
        return fftSetup.perform(on: self, direction)
    }

}

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

extension Matrix {
    /// Create a reference to an fftSetup object
    /// You are resonsible for calling `vDSP_destroy_fftsetupD()` when it is no longer required
    func createVdspFftSetup() -> FFTSetupD {
        let log2Size = UInt(log2(Double(n)))

        guard let fftSetup = vDSP_create_fftsetupD(log2Size, FFTRadix(kFFTRadix2)) else {
            fatalError("Could not initialize FFT Setup")
        }

        return fftSetup
    }
}
