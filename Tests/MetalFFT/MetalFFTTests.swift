import XCTest


class FFTTests: XCTestCase {

    func testFFTSimple1() throws {
        let width = 2
        let height = 2

        let matrix = Matrix<Float>(shape: (height, width), flat: [
            1, 0,
            0, 0
        ])

        let expectedResult: [[(Float, Float)]] = [
            [(1.0, 0.0), (1.0, 0.0)],
            [(1.0, 0.0), (1.0, 0.0)]
        ]

        let metalFftComputer = FFT(size: (height, width))
        let metalFftResult = metalFftComputer.execute(input: matrix.map({ Complex<Float>(Float($0), 0.0) }))

        for i in 0..<height {
            for j in 0..<width {
                XCTAssertEqual(metalFftResult[i, j].real, expectedResult[i][j].0, accuracy: 0.001, "(\(i),\(j)) not equal")
                XCTAssertEqual(metalFftResult[i, j].imaginary, expectedResult[i][j].1, accuracy: 0.001, "(\(i),\(j)) not equal")
            }
        }
    }

    func testFFTSimple2() throws {
        let width = 2
        let height = 2

        let matrix = Matrix<Float>(shape: (height, width), flat: [
            1, 1,
            0, 0
        ])

        let expectedResult: [[(Float, Float)]] = [
            [(2.0, 0.0), (0.0, 0.0)],
            [(2.0, 0.0), (0.0, 0.0)]
        ]

        let metalFftComputer = FFT(size: (height, width))
        let metalFftResult = metalFftComputer.execute(input: matrix.map({ Complex<Float>(Float($0), 0.0) }))

        print(metalFftResult)

        for i in 0..<height {
            for j in 0..<width {
                XCTAssertEqual(metalFftResult[i, j].real, expectedResult[i][j].0, accuracy: 0.001, "(\(i),\(j)) not equal")
                XCTAssertEqual(metalFftResult[i, j].imaginary, expectedResult[i][j].1, accuracy: 0.001, "(\(i),\(j)) not equal")
            }
        }
    }


    func testFFTComplex() throws {
        let width = 4
        let height = 2

        let matrix = Matrix<Float>(shape: (height, width), flat: [
            1, -2,   3,   4,
            3,  4.5, 5,   6
        ])

        // Numpy result:
        // [[ 24.5+0.j   -4. +7.5j  -0.5+0.j   -4. -7.5j]
        //  [-12.5+0.j    0. +4.5j   4.5+0.j    0. -4.5j]]

        let expectedResult: [[(Float, Float)]] = [
            [(24.5, 0.0), (-4.0, 7.5),  (-0.5, 0.0), (-4.0, -7.5)],
            [(-12.5, 0.0), (0.0, 4.5), (4.5, 0.0), (0.0, -4.5)]
        ]

        let metalFftComputer = FFT(size: (height, width))
        let metalFftResult = metalFftComputer.execute(input: matrix.map({ Complex<Float>(Float($0), 0.0) }))

        print(metalFftResult)

        for i in 0..<height {
            for j in 0..<width {
                XCTAssertEqual(metalFftResult[i, j].real, expectedResult[i][j].0, accuracy: 0.001, "(\(i),\(j)) not equal")
                XCTAssertEqual(metalFftResult[i, j].imaginary, expectedResult[i][j].1, accuracy: 0.001, "(\(i),\(j)) not equal")
            }
        }

    }
}
