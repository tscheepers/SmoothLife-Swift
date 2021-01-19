import Foundation


// MARK: - Complex values
struct ComplexDouble : CustomDebugStringConvertible, Numeric {

    init?<T>(exactly source: T) where T : BinaryInteger {
        self.real = Double(source)
        self.imaginary = 0.0
    }

    init(integerLiteral value: IntegerLiteralType) {
        self.real = Double(value)
        self.imaginary = 0.0
    }

    init(_ real: Double, _ imaginary: Double) {
        self.real = real
        self.imaginary = imaginary
    }

    var real: Double
    var imaginary: Double

    public var radiusSquare: Double { return real * real + imaginary * imaginary }

    var debugDescription: String {
        return "\(real) + \(imaginary)i"
    }

    public var magnitude: Double {
        return max(abs(real), abs(imaginary))
    }

    var conjugate: Self {
        return ComplexDouble(real, -imaginary)
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        return ComplexDouble(lhs.real + rhs.real, lhs.imaginary + rhs.imaginary)
    }

    static func + (lhs: Self, rhs: Double) -> Self {
        return ComplexDouble(lhs.real + rhs, lhs.imaginary)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        return ComplexDouble(lhs.real - rhs.real, lhs.imaginary - rhs.imaginary)
    }

    static func - (lhs: Self, rhs: Double) -> Self {
        return ComplexDouble(lhs.real - rhs, lhs.imaginary)
    }

    static func * (lhs: Self, rhs: Self) -> Self {
        return ComplexDouble(lhs.real * rhs.real - lhs.imaginary * rhs.imaginary, lhs.real * rhs.imaginary + lhs.imaginary * rhs.real)
    }

    static func * (lhs: Self, rhs: Double) -> Self {
        return ComplexDouble(lhs.real * rhs, lhs.real * rhs)
    }

    static func *= (lhs: inout ComplexDouble, rhs: ComplexDouble) {
        lhs = lhs * rhs
    }

    static public func / (lhs: Self, rhs: Self) -> Self {
        return lhs * (rhs.conjugate / rhs.radiusSquare)
    }

    static public func / (lhs: Self, rhs: Double) -> Self  {
        return ComplexDouble(lhs.real / rhs, lhs.imaginary / rhs)
    }
}
