import XCTest


class vDSPFFTTests: XCTestCase {

    func testvDSPFFTSimple() throws {

        let matrix = Matrix<Float>(shape: (2, 4), flat: [
            1, -2,   3,   4,
            3,  4.5, 5,   6
        ])

        let expectedResult: [[(Float,Float)]] = [
            [(24.5, 0.0), (-4.0, 7.5),  (-0.5, 0.0), (-4.0, -7.5)],
            [(-12.5, 0.0), (0.0,4.5), (4.5, 0.0), (0.0, -4.5)]
        ]

        let vdspFftResult = matrix.vdspFft()

        SLSAssertEqual(vdspFftResult, expectedResult, accuracy: 0.001)
    }

    func testvDSPFFT() throws {
        let matrix = Matrix<Float>(shape: (16, 16), flat: Fixtures.fftTestInput.flatMap({ $0 })).map({ Complex($0, 0.0) })
        let vdspFftResult = matrix.vdspFft()

        SLSAssertEqual(vdspFftResult, Fixtures.fftTestOutput, accuracy: 0.001)
    }
}
