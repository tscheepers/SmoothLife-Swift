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
        return Matrix(shape: shape, flat: Array(self.flat.suffix(from: rows) + self.flat.prefix(rows)))
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

// MARK: - Complex
extension Matrix where T == ComplexDouble {
    var real: Matrix<Double> {
        return Matrix<Double>(shape: shape, flat: flat.map({ $0.real }))
    }

    func fft(_ direction: vDSP.FourierTransformDirection = .forward) -> Matrix<ComplexDouble> {

        let reals = UnsafeMutableBufferPointer<Double>.allocate(capacity: n)
        let imags =  UnsafeMutableBufferPointer<Double>.allocate(capacity: n)

        _ = reals.initialize(from: flat.map({ $0.real }))
        _ = imags.initialize(from: flat.map({ $0.imaginary }))

        var complexBuffer = DSPDoubleSplitComplex(realp: reals.baseAddress!, imagp: imags.baseAddress!)
        let log2Size = UInt(log2(Double(n)))
        let log2Width = UInt(log2(Double(width)))
        let log2Height = UInt(log2(Double(height)))

        guard let fftSetup = vDSP_create_fftsetupD(log2Size, FFTRadix(kFFTRadix2)) else {
            fatalError("Could not initialize FFT Setup")
        }

        switch direction {
        case .forward:
            vDSP_fft2d_zipD(fftSetup, &complexBuffer, 1, 0, log2Width, log2Height, FFTDirection(FFT_FORWARD))
        case .inverse:
            vDSP_fft2d_zipD(fftSetup, &complexBuffer, 1, 0, log2Width, log2Height, FFTDirection(FFT_INVERSE))
        @unknown default:
            fatalError("Unkown direction")
        }

        let flat = zip(reals, imags).map({ ComplexDouble($0.0, $0.1) })

        defer {
            imags.deallocate()
            reals.deallocate()
            vDSP_destroy_fftsetupD(fftSetup)
        }

        return Matrix<ComplexDouble>(shape: shape, flat: flat)
    }
}

// MARK: - Floating point matrices
extension Matrix where T == Double {

    /// The sum of the matrix
    var sum: T {
        return flat.reduce(0.0, { $0 + $1 })
    }

    /// Fill a metal texture with the matrix
    func fill(texture: MTLTexture) {
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: flat.map({ Float($0) }),
            bytesPerRow: width * MemoryLayout<Float>.stride
        )
    }

    func fft(_ direction: vDSP.FourierTransformDirection = .forward) -> Matrix<ComplexDouble> {
        return self.complex.fft(direction)
    }

    var complex: Matrix<ComplexDouble> {
        return self.map({ ComplexDouble($0, 0.0) })
    }
}

extension Matrix where T == Float {

    static func copy(fromTexture texture: MTLTexture) -> Matrix<Float> {

        let n =  texture.height * texture.width
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: n * MemoryLayout<Float>.stride, alignment: MemoryLayout<Float>.alignment)
        texture.getBytes(
            pointer,
            bytesPerRow: texture.width * MemoryLayout<Float>.stride,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0
        )

        let typedPointer = pointer.bindMemory(to: Float.self, capacity: n)

        let flat = Array(UnsafeBufferPointer(start: typedPointer, count: n))

        return Matrix<Float>(shape: (height: texture.height, width: texture.width), flat: flat)
    }
}

// MARK: - Initializers
extension Matrix {

    /// Returns a matrix filled with zeros
    static func zeros(shape: (height: Int, width: Int)) -> Matrix<T> where T : AdditiveArithmetic {
        let flat = [T](repeating: T.zero, count: shape.height * shape.width)
        return Matrix<T>(shape: shape, flat: flat)
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
    static func meshGrid(shape: (height: Int, width: Int)) -> (Matrix<Double>, Matrix<Double>) {

        let n = shape.height * shape.width
        var xs = [Double](repeating: Double.zero, count: n)
        var ys = [Double](repeating: Double.zero, count: n)

        for i in 0..<n {
            xs[i] = Double(i / shape.width)
            ys[i] = Double(i % shape.width)
        }

        return (Matrix<Double>(shape: shape, flat: xs), Matrix<Double>(shape: shape, flat: ys))
    }
}

// MARK: - Elementwise operators
extension Matrix where T : AdditiveArithmetic {

    
    // PLUS
    static func + (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes not valid")
        return Matrix(shape: lhs.shape, flat: zip(lhs.flat, rhs.flat).map({ $0.0 + $0.1 }))
    }
    static func + (lhs: T, rhs: Matrix<T>) -> Matrix<T> {
        return Matrix(shape: rhs.shape, flat: rhs.flat.map({ lhs + $0 }))
    }
    static func + (lhs: Matrix<T>, rhs: T) -> Matrix<T> {
        return Matrix(shape: lhs.shape, flat: lhs.flat.map({ $0 + rhs }))
    }

    // MINUS
    static func - (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes not valid")
        return Matrix(shape: lhs.shape, flat: zip(lhs.flat, rhs.flat).map({ $0.0 - $0.1 }))
    }
    static func - (lhs: T, rhs: Matrix<T>) -> Matrix<T> {
        return Matrix(shape: rhs.shape, flat: rhs.flat.map({ lhs - $0 }))
    }
    static func - (lhs: Matrix<T>, rhs: T) -> Matrix<T> {
        return Matrix(shape: lhs.shape, flat: lhs.flat.map({ $0 - rhs }))
    }
}

extension Matrix where T : Numeric {
    // TIMES
    static func * (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes not valid")
        return Matrix(shape: lhs.shape, flat: zip(lhs.flat, rhs.flat).map({ $0.0 * $0.1 }))
    }
    static func * (lhs: T, rhs: Matrix<T>) -> Matrix<T> {
        return Matrix(shape: rhs.shape, flat: rhs.flat.map({ lhs * $0 }))
    }
    static func * (lhs: Matrix<T>, rhs: T) -> Matrix<T> {
        return Matrix(shape: lhs.shape, flat: lhs.flat.map({ $0 * rhs }))
    }
}

extension Matrix where T : FloatingPoint {
    // DIVIDE
    static func / (lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        assert(lhs.shape == rhs.shape, "Shapes not valid")
        return Matrix(shape: lhs.shape, flat: zip(lhs.flat, rhs.flat).map({ $0.0 / $0.1 }))
    }

    static func / (lhs: T, rhs: Matrix<T>) -> Matrix<T> {
        return Matrix(shape: rhs.shape, flat: rhs.flat.map({ lhs / $0 }))
    }

    static func / (lhs: Matrix<T>, rhs: T) -> Matrix<T> {
        return Matrix(shape: lhs.shape, flat: lhs.flat.map({ $0 / rhs }))
    }
}

// MARK: - Math functions
// POWER FUNCTION
func pow(_ x: Matrix<Double>, power: Double) -> Matrix<Double> {
    return Matrix(shape: x.shape, flat: x.flat.map({ pow($0, power) }))
}

func sqrt(_ x: Matrix<Double>) -> Matrix<Double> {
    return Matrix(shape: x.shape, flat: x.flat.map({ sqrt($0) }))
}

func exp(_ x: Matrix<Double>) -> Matrix<Double> {
    return Matrix(shape: x.shape, flat: x.flat.map({ exp($0) }))
}
