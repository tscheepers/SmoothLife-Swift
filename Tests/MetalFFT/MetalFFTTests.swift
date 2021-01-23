import XCTest


class MetalFFTTests: XCTestCase {

    func testFFTSimple1() throws {

        let matrix = Matrix<Float>(shape: (2, 2), flat: [
            1, 0,
            0, 0
        ]).map({ Complex<Float>($0, 0.0) })

        let expectedResult: [[(Float, Float)]] = [
            [(1.0, 0.0), (1.0, 0.0)],
            [(1.0, 0.0), (1.0, 0.0)]
        ]

        let metalFftResult = matrix.metalFft()

        SLSAssertEqual(metalFftResult, expectedResult, accuracy: 0.001)

        let metalFftInverseResult = metalFftResult.metalFft(.inverse)

        SLSAssertEqual(metalFftInverseResult, matrix, accuracy: 0.001)
    }

    func testFFTSimple2() throws {

        let matrix = Matrix<Float>(shape: (2, 2), flat: [
            1, 1,
            0, 0
        ]).map({ Complex<Float>($0, 0.0) })

        let expectedResult: [[(Float, Float)]] = [
            [(2.0, 0.0), (0.0, 0.0)],
            [(2.0, 0.0), (0.0, 0.0)]
        ]

        let metalFftResult = matrix.metalFft()

        SLSAssertEqual(metalFftResult, expectedResult, accuracy: 0.001)

        let metalFftInverseResult = metalFftResult.metalFft(.inverse)

        SLSAssertEqual(metalFftInverseResult, matrix, accuracy: 0.001)
    }


    func testFFTSimple3() throws {

        let matrix = Matrix<Float>(shape: (2, 4), flat: [
            1, -2,   3,   4,
            3,  4.5, 5,   6
        ]).map({ Complex<Float>($0, 0.0) })

        let expectedResult: [[(Float, Float)]] = [
            [(24.5, 0.0), (-4.0, 7.5),  (-0.5, 0.0), (-4.0, -7.5)],
            [(-12.5, 0.0), (0.0, 4.5), (4.5, 0.0), (0.0, -4.5)]
        ]

        let metalFftResult = matrix.metalFft()

        SLSAssertEqual(metalFftResult, expectedResult, accuracy: 0.001)

        let metalFftInverseResult = metalFftResult.metalFft(.inverse)

        SLSAssertEqual(metalFftInverseResult, matrix, accuracy: 0.001)
    }

    func testFFT() throws {

        let matrix = Matrix<Double>(shape: (16, 16), flat: Fixtures.fftTestInput.flatMap({ $0 }))

        let metalFftResult = matrix.metalFft()

        SLSAssertEqual(metalFftResult, Fixtures.fftTestOutput, accuracy: 0.002)
    }

    func testFFTInverse() throws {

        let matrix = Matrix<Complex<Float>>(shape: (16, 16), flat: Fixtures.fftTestOutput.flatMap({ $0 })
                                                .map({ Complex<Float>(Float($0.0), Float($0.1)) }) )

        let metalFffResult = matrix.metalFft(.inverse).map { Double($0.real) }

        SLSAssertEqual(metalFffResult, Fixtures.fftTestInput, accuracy: 0.001)
    }

}
