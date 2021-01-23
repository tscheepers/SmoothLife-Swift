import Foundation

class Fixtures {

    /// Cords for creating a starts state field
    static let startStateCords : [(Int, Int)] = [
        (51, 0),
        (28, 4),
        (46, 24),
        (34, 14),
        (10, 26),
        (23, 19),
        (8, 29)
    ]

    /// A 64x64 field start state that should result in a nice glider
    static let startState : [[Float]] = Fixtures.loadCSV(named: "StartState")

    /// A 64x64 smooth circle with an inner radius of 4.0
    static let circleInnerRadius : [[Float]] = Fixtures.loadCSV(named: "CircleInnerRadius")

    /// FFT applied to the smooth circle with an inner radius of 4.0
    static let effectiveCellKernelInFd : [[Float]] = Fixtures.loadCSV(named: "EffectiveCellKernelInFd")

    /// FFT applied to the start state field
    static let fftOnVirginField : [[(Float, Float)]] = Fixtures.loadComplexCSV(named: "FftOnVirginField")

    /// The result of applying the effectiveCell kernel to the virgin field
    static let effectiveCellKernelAppliedToField : [[Float]] = Fixtures.loadCSV(named: "EffectiveCellKernelAppliedToField")

    /// The result of applying the transition function to M and N for the first iteration
    static let transitionResult : [[Float]] = Fixtures.loadCSV(named: "TransitionResult")

    /// Randomly generated input to test FFT
    static let fftTestInput : [[Float]] = Fixtures.loadCSV(named: "FftTestInput")

    /// Randomly generated output to test FFT (generated with Numpy)
    static let fftTestOutput : [[(Float, Float)]] = Fixtures.loadComplexCSV(named: "FftTestOutput")

    /// Method to load data from CSV
    static func loadCSV(named: String) -> [[Float]] {

        let url =  Bundle(for: Self.self).url(forResource: named, withExtension: "csv")
        let contents = try! String(contentsOf: url!)

        return contents
            .components(separatedBy: "\n")
            .compactMap { $0 == "" ? nil : $0.components(separatedBy: ",").map { Float(Double($0.trimmingCharacters(in: .whitespaces))!) } }
    }

    /// Method to load complex data from CSV
    static func loadComplexCSV(named: String) -> [[(Float, Float)]] {
        let url =  Bundle(for: Self.self).url(forResource: named, withExtension: "csv")
        let contents = try! String(contentsOf: url!)

        return contents
            .components(separatedBy: "\n")
            .compactMap { $0 == "" ? nil : $0.components(separatedBy: ",").map { s -> (Float, Float) in
                let c = s.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
                return (Float(Double(c.first!)!), Float(Double(c.last!)!))
            } }
    }

}

