import Metal
import Foundation
import UIKit
import Accelerate

// MARK: - Matrix
struct Matrix<T> {

    var shape: (height: Int, width: Int)
    var height: Int { return shape.0 }
    var width: Int { return shape.1 }
    var n: Int { return width * height }
    
    var flat: [T]

    init(shape: (height: Int, width: Int), flat: [T]) {
        assert(flat.count == shape.height * shape.width, "Flat does not correspond with shape")
        self.shape = shape
        self.flat = flat
    }

    /// Access the matrix using `matrix[x,y]`
    subscript(row: Int, col: Int) -> T {
        get {
            assert(row >= 0 && row < height, "Row index out of range")
            assert(col >= 0 && col < width, "Col index out of range")
            return self.flat[(row * width) + col]
        }
        set {
            assert(row >= 0 && row < height, "Row index out of range")
            assert(col >= 0 && col < width, "Col index out of range")
            self.flat[(row * width) + col] = newValue
        }
    }

    /// Roll over the matrix on its rows [A, B, C] -> [C, A, B]
    func roll(rows: Int) -> Matrix {
        return Matrix(shape: shape, flat: Array(self.flat.suffix(from: rows * width) + self.flat.prefix(rows * width)))
    }

    /// Roll over the matrix on its columns [A, B, C] -> [C, A, B]
    func roll(cols: Int) -> Matrix {
        var newFlat = Array(flat)
        for row in 0..<height {
            for col in 0..<width {
                newFlat[row * width + col] = flat[row * width + ((col + cols) % width)]
            }
        }
        return Matrix(shape: shape, flat: newFlat)
    }

    func map<A>(_ transform: (T) throws -> A) rethrows -> Matrix<A> {
        return Matrix<A>(shape: shape, flat: try flat.map(transform))
    }
}

// MARK: - Debug
extension Matrix: CustomDebugStringConvertible {

    /// Printing out the matrix in a nice readable format
    var debugDescription: String {
        var string = "height: \(height) width: \(width)\n ["
        for row in 0..<height {
            string.append("[")
            for col in 0..<width {
                if col == width - 1 {
                    string.append("\(self[row, col])")
                } else {
                    string.append("\(self[row, col]), ")
                }
            }
            string.append("]\n")
        }
        string.append("]")
        return string
    }
}

// MARK: - Double
extension Matrix where T == Double {

    /// The sum of the matrix
    var sum: T {
        return flat.reduce(0.0, { $0 + $1 })
    }

    var complex: Matrix<Complex<T>> {
        return self.map({ Complex<T>($0, 0.0) })
    }

    func hardStep(_ boundary: T = 0.5) -> Matrix<T> {
        return self.map { (value) -> T in
            if value > boundary {
                return 1.0
            } else {
                return 0.0
            }
        }
    }

    func clamp(_ between: (T, T) = (0.0, 1.0)) -> Matrix<T> {
        return self.map { (value) -> T in
            if value < between.0 {
                return between.0
            } else if value > between.1 {
                return between.1
            }
            return value
        }
    }

    /// Returns two grids in the style:
    /// ```
    /// [[0, 0, 0, 0, 0],
    ///  [1, 1, 1, 1, 1],
    ///  [2, 2, 2, 2, 2],
    ///  [3, 3, 3, 3, 3],
    ///  [4, 4, 4, 4, 4]]
    /// and
    /// [[0, 1, 2, 3, 4],
    ///  [0, 1, 2, 3, 4],
    ///  [0, 1, 2, 3, 4],
    ///  [0, 1, 2, 3, 4],
    ///  [0, 1, 2, 3, 4]]
    /// ```
    static func meshGrid(shape: (height: Int, width: Int)) -> (Matrix<T>, Matrix<T>) {

        let n = shape.height * shape.width
        var xs = [T](repeating: T.zero, count: n)
        var ys = [T](repeating: T.zero, count: n)

        for i in 0..<n {
            xs[i] = T(i / shape.width)
            ys[i] = T(i % shape.width)
        }

        return (Matrix<T>(shape: shape, flat: xs), Matrix<T>(shape: shape, flat: ys))
    }

    func fill(texture: MTLTexture) {
        self.map({ Float($0) }).fill(texture: texture)
    }

    // MARK: Fast vDSP methods specific to Double

    func fft(_ direction: vDSP.FourierTransformDirection = .forward, reuseSetup setup: FFTSetupD? = nil) -> Matrix<Complex<Double>> {
        return self.complex.fft(direction, reuseSetup: setup)
    }

    // PLUS
    static func + (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes invalid")
        var result = Matrix.zeros(shape: lhs.shape)
        rhs.flat.withUnsafeBufferPointer{ srcR in
            lhs.flat.withUnsafeBufferPointer{ srcL in
                result.flat.withUnsafeMutableBufferPointer{ dst in
                    vDSP_vaddD(srcR.baseAddress!, 1, srcL.baseAddress!, 1, dst.baseAddress!, 1, vDSP_Length(lhs.n))
                }
            }
        }
        return result
    }
    static func + (lhs: Matrix<T>, rhs: T) -> Matrix<T> {
        var result = lhs
        lhs.flat.withUnsafeBufferPointer{ src in
            result.flat.withUnsafeMutableBufferPointer{ dst in
                var scalar = rhs
                vDSP_vsaddD(src.baseAddress!, 1, &scalar, dst.baseAddress!, 1, vDSP_Length(lhs.n))
            }
        }
        return result
    }
    static func + (lhs: T, rhs: Matrix<T>) -> Matrix<T> {
        return rhs + lhs
    }

    // MINUS
    static func - (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes invalid")
        var result = Matrix.zeros(shape: lhs.shape)
        rhs.flat.withUnsafeBufferPointer{ srcR in
            lhs.flat.withUnsafeBufferPointer{ srcL in
                result.flat.withUnsafeMutableBufferPointer{ dst in
                    vDSP_vsubD(srcR.baseAddress!, 1, srcL.baseAddress!, 1, dst.baseAddress!, 1, vDSP_Length(lhs.n))
                }
            }
        }
        return result
    }
    static func - (lhs: Matrix<T>, rhs: T) -> Matrix<T> {
        return lhs + (-rhs)
    }
    static func - (lhs: T, rhs: Matrix<T>) -> Matrix<T> {
        var result = rhs
        result.flat.withUnsafeMutableBufferPointer{ dst in
            var scalar = lhs
            let length = vDSP_Length(rhs.n)
            vDSP_vnegD(dst.baseAddress!, 1, dst.baseAddress!, 1, length)
            vDSP_vsaddD(dst.baseAddress!, 1, &scalar, dst.baseAddress!, 1, length)
        }
        return result
    }

    // TIMES
    static func * (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes invalid")
        var result = Matrix.zeros(shape: lhs.shape)
        rhs.flat.withUnsafeBufferPointer{ srcR in
            lhs.flat.withUnsafeBufferPointer{ srcL in
                result.flat.withUnsafeMutableBufferPointer{ dst in
                    vDSP_vmulD(srcR.baseAddress!, 1, srcL.baseAddress!, 1, dst.baseAddress!, 1, vDSP_Length(lhs.n))
                }
            }
        }
        return result
    }
    static func * (lhs: Matrix<T>, rhs: T) -> Matrix<T> where T == Double {
        var result = lhs
        lhs.flat.withUnsafeBufferPointer{ src in
            result.flat.withUnsafeMutableBufferPointer{ dst in
                var scalar = rhs
                vDSP_vsmulD(src.baseAddress!, 1, &scalar, dst.baseAddress!, 1, vDSP_Length(lhs.n))
            }
        }
        return result
    }
    static func * (lhs: T, rhs: Matrix<T>) -> Matrix<T> {
        return rhs * lhs
    }

    // DIVIDE
    static func / (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes invalid")
        var result = Matrix.zeros(shape: lhs.shape)
        rhs.flat.withUnsafeBufferPointer{ srcR in
            lhs.flat.withUnsafeBufferPointer{ srcL in
                result.flat.withUnsafeMutableBufferPointer{ dst in
                    vDSP_vdivD(srcR.baseAddress!, 1, srcL.baseAddress!, 1, dst.baseAddress!, 1, vDSP_Length(lhs.n))
                }
            }
        }
        return result
    }
    static func / (lhs: Matrix<T>, rhs: T) -> Matrix<T> {
        var result = lhs
        lhs.flat.withUnsafeBufferPointer{ src in
            result.flat.withUnsafeMutableBufferPointer{ dst in
                var scalar = rhs
                vDSP_vsdivD(src.baseAddress!, 1, &scalar, dst.baseAddress!, 1, vDSP_Length(lhs.n))
            }
        }
        return result
    }
    static func / (lhs: T, rhs: Matrix<T>) -> Matrix<T> {
        var result = rhs
        rhs.flat.withUnsafeBufferPointer{ src in
            result.flat.withUnsafeMutableBufferPointer{ dst in
                var scalar = lhs
                vDSP_svdivD(&scalar, src.baseAddress!, 1, dst.baseAddress!, 1, vDSP_Length(rhs.n))
            }
        }
        return result
    }
}

/// Power function
func pow(_ x: Matrix<Double>, power: Double) -> Matrix<Double> {
    var result = x
    x.flat.withUnsafeBufferPointer { src in
        result.flat.withUnsafeMutableBufferPointer { dst in
            if power == 2 {
                vDSP_vsqD(src.baseAddress!, 1, dst.baseAddress!, 1, vDSP_Length(x.width * x.height))
            } else {
                var size = Int32(x.width * x.height)
                var exponent = power
                vvpows(dst.baseAddress!, &exponent, src.baseAddress!, &size)
            }
        }
    }
    return result
}

/// Square root function
func sqrt(_ x: Matrix<Double>) -> Matrix<Double> {
    var result = x
    x.flat.withUnsafeBufferPointer { src in
        result.flat.withUnsafeMutableBufferPointer { dst in
            var size = Int32(x.width * x.height)
            vvsqrt(dst.baseAddress!, src.baseAddress!, &size)
        }
    }
    return result
}

/// Exponential function
func exp(_ x: Matrix<Double>) -> Matrix<Double> {
    var result = x
    x.flat.withUnsafeBufferPointer { src in
        result.flat.withUnsafeMutableBufferPointer { dst in
            var size = Int32(x.width * x.height)
            vvexp(dst.baseAddress!, src.baseAddress!, &size)
        }
    }
    return result
}

// MARK: - Complex
extension Matrix where T == Complex<Double> {
    var real: Matrix<Double> {
        return self.map({ $0.real })
    }

    // MARK: Fast vDSP methods specific to Complex<Double>

    func fft(_ direction: vDSP.FourierTransformDirection = .forward, reuseSetup setup: FFTSetupD? = nil) -> Matrix<Complex<Double>> {

        let reals = UnsafeMutableBufferPointer<Double>.allocate(capacity: n)
        let imags =  UnsafeMutableBufferPointer<Double>.allocate(capacity: n)

        _ = reals.initialize(from: flat.map({ $0.real }))
        _ = imags.initialize(from: flat.map({ $0.imaginary }))

        var complexBuffer = DSPDoubleSplitComplex(realp: reals.baseAddress!, imagp: imags.baseAddress!)

        // If no reusable fft setup is specified we'll create a one-off
        let fftSetup = setup ?? self.createFftSetup()
        let log2Width = UInt(log2(Double(width)))
        let log2Height = UInt(log2(Double(height)))

        vDSP_fft2d_zipD(fftSetup, &complexBuffer, 1, 0, log2Width, log2Height, direction.fftDirection)

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

    // TIMES
    static func * (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes invalid")
        return Matrix(shape: lhs.shape, flat: zip(lhs.flat, rhs.flat).map({ $0.0 * $0.1 }))
    }
}

extension Matrix {
    /// Create a reference to an fftSetup object
    /// You are resonsible for calling `vDSP_destroy_fftsetupD()` when it is no longer required
    func createFftSetup() -> FFTSetupD {
        let log2Size = UInt(log2(Double(n)))

        guard let fftSetup = vDSP_create_fftsetupD(log2Size, FFTRadix(kFFTRadix2)) else {
            fatalError("Could not initialize FFT Setup")
        }

        return fftSetup
    }
}

// MARK: - Float
extension Matrix where T == Float {

    /// Create a matrix from a texture (float2)
    static func copy(fromTexture texture: MTLTexture) -> Matrix<T> {

        let n =  texture.height * texture.width
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: n * MemoryLayout<T>.stride, alignment: MemoryLayout<T>.alignment)
        texture.getBytes(
            pointer,
            bytesPerRow: texture.width * MemoryLayout<T>.stride,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0
        )

        let typedPointer = pointer.bindMemory(to: Float.self, capacity: n)

        let flat = Array(UnsafeBufferPointer(start: typedPointer, count: n))

        return Matrix<T>(shape: (height: texture.height, width: texture.width), flat: flat)
    }

    /// Fill a metal texture with the matrix
    func fill(texture: MTLTexture) {
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: flat,
            bytesPerRow: width * MemoryLayout<T>.stride
        )
    }
}

extension Matrix where T == Complex<Float> {

    /// Create a matrix from a texture (float2)
    static func copy(fromTexture texture: MTLTexture) -> Matrix<T> {

        let n = texture.height * texture.width
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: n * MemoryLayout<Complex<Float>>.stride, alignment: MemoryLayout<T>.alignment)
        texture.getBytes(
            pointer,
            bytesPerRow: texture.width * MemoryLayout<Complex<Float>>.stride,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0
        )

        let typedPointer = pointer.bindMemory(to: Complex<Float>.self, capacity: n)

        let flat = Array(UnsafeBufferPointer(start: typedPointer, count: n))

        return Matrix<T>(shape: (height: texture.height, width: texture.width), flat: flat)
    }

    /// Fill a metal texture with the matrix
    func fill(texture: MTLTexture) {
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: flat,
            bytesPerRow: width * MemoryLayout<Complex<Float>>.stride
        )
    }
}

// MARK: - Initializers
extension Matrix {

    /// Returns a matrix filled with zeros
    static func zeros(shape: (height: Int, width: Int)) -> Matrix<T> where T : AdditiveArithmetic {
        let flat = [T](repeating: T.zero, count: shape.height * shape.width)
        return Matrix<T>(shape: shape, flat: flat)
    }

}

// MARK: - Elementwise operators
extension Matrix where T : AdditiveArithmetic {

    // PLUS
    static func + (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes invalid")
        return Matrix(shape: lhs.shape, flat: zip(lhs.flat, rhs.flat).map({ $0.0 + $0.1 }))
    }
    static func + (lhs: Matrix<T>, rhs: T) -> Matrix<T> {
        return lhs.map({ $0 + rhs })
    }
    static func + (lhs: T, rhs: Matrix<T>) -> Matrix<T> {
        return rhs + lhs
    }

    // MINUS
    static func - (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes invalid")
        return Matrix(shape: lhs.shape, flat: zip(lhs.flat, rhs.flat).map({ $0.0 - $0.1 }))
    }
    static func - (lhs: Matrix<T>, rhs: T) -> Matrix<T> {
        return lhs.map({ $0 - rhs })
    }
    static func - (lhs: T, rhs: Matrix<T>) -> Matrix<T> {
        return rhs.map({ lhs - $0 })
    }
}

extension Matrix where T : Numeric {
    // TIMES
    static func * (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes invalid")
        return Matrix(shape: lhs.shape, flat: zip(lhs.flat, rhs.flat).map({ $0.0 * $0.1 }))
    }
    static func * (lhs: Matrix<T>, rhs: T) -> Matrix<T> {
        return lhs.map({ $0 * rhs })
    }
    static func * (lhs: T, rhs: Matrix<T>) -> Matrix<T> {
        return rhs * lhs
    }
}

extension Matrix where T : FloatingPoint {
    // DIVIDE
    static func / (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes invalid")
        return Matrix(shape: lhs.shape, flat: zip(lhs.flat, rhs.flat).map({ $0.0 / $0.1 }))
    }
    static func / (lhs: Matrix<T>, rhs: T) -> Matrix<T> {
        return lhs.map({ $0 / rhs })
    }
    static func / (lhs: T, rhs: Matrix<T>) -> Matrix<T> {
        return rhs.map({ lhs / $0 })
    }
}
