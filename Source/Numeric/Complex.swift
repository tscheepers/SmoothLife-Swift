import Foundation


// MARK: - Complex values
struct Complex<T> : CustomDebugStringConvertible, Numeric where T : FloatingPoint {

    var real: T
    var imaginary: T

    init?<Source>(exactly source: Source) where Source : BinaryInteger {
        self.real = T(source)
        self.imaginary = T.zero
    }

    init(integerLiteral value: IntegerLiteralType) {
        self.real = T(value)
        self.imaginary = T.zero
    }

    init(_ real: T, _ imaginary: T) {
        self.real = real
        self.imaginary = imaginary
    }

    public var radiusSquare: T { return real * real + imaginary * imaginary }

    var debugDescription: String {
        return "\(real) + \(imaginary)i"
    }

    public var magnitude: T {
        return max(abs(real), abs(imaginary))
    }

    var conjugate: Self {
        return Self(real, -imaginary)
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        return Self(lhs.real + rhs.real, lhs.imaginary + rhs.imaginary)
    }

    static func + (lhs: Self, rhs: T) -> Self {
        return Self(lhs.real + rhs, lhs.imaginary)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        return Self(lhs.real - rhs.real, lhs.imaginary - rhs.imaginary)
    }

    static func - (lhs: Self, rhs: T) -> Self {
        return Self(lhs.real - rhs, lhs.imaginary)
    }

    static func * (lhs: Self, rhs: Self) -> Self {
        return Self(lhs.real * rhs.real - lhs.imaginary * rhs.imaginary, lhs.real * rhs.imaginary + lhs.imaginary * rhs.real)
    }

    static func * (lhs: Self, rhs: T) -> Self {
        return Self(lhs.real * rhs, lhs.real * rhs)
    }

    static func *= (lhs: inout Self, rhs: Self) {
        lhs = lhs * rhs
    }

    static public func / (lhs: Self, rhs: Self) -> Self {
        return lhs * (rhs.conjugate / rhs.radiusSquare)
    }

    static public func / (lhs: Self, rhs: T) -> Self  {
        return Self(lhs.real / rhs, lhs.imaginary / rhs)
    }
}
