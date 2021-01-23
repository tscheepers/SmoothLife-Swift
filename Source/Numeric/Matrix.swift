import Metal
import Foundation

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

// MARK: - Float
extension Matrix where T == Float {

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
}

extension Matrix where T : FloatingPoint {

    /// The sum of the matrix
    var sum: T {
        return flat.reduce(T.zero, { $0 + $1 })
    }

    /// Transform to complex matrix
    var complex: Matrix<Complex<T>> {
        return self.map { Complex<T>($0, T.zero) }
    }

    /// Returns a matrix filled with zeros
    static func zeros(shape: (height: Int, width: Int)) -> Matrix<T> {
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
}



// MARK: - Complex

extension Matrix where T == Complex<Float> {
    var real: Matrix<Float> {
        return self.map({ $0.real })
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


