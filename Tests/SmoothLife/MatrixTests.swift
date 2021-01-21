import XCTest


class MatrixTests: XCTestCase {

    func testRollCols() throws {
        let matrix = Matrix<Double>(shape: (3,3), flat: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0])
        let rolled = matrix.roll(cols: 2)

        XCTAssertEqual(rolled.flat, [3.0, 1.0, 2.0, 6.0, 4.0, 5.0, 9.0, 7.0, 8.0])
    }

    func testRollRows() throws {
        let matrix = Matrix<Double>(shape: (3,3), flat: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0])
        let rolled = matrix.roll(rows: 2)

        XCTAssertEqual(rolled.flat, [7.0, 8.0, 9.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
    }

    func testvDSPFFT() throws {
        let width = 4
        let height = 2

        let matrix = Matrix<Double>(shape: (height, width), flat: [
            1, -2,   3,   4,
            3,  4.5, 5,   6
        ])

        // Numpy result:
        // [[ 24.5+0.j   -4. +7.5j  -0.5+0.j   -4. -7.5j]
        //  [-12.5+0.j    0. +4.5j   4.5+0.j    0. -4.5j]]

        let expectedResult = [
            [(24.5, 0.0), (-4.0, 7.5),  (-0.5, 0.0), (-4.0, -7.5)],
            [(-12.5, 0.0), (0.0,4.5), (4.5, 0.0), (0.0, -4.5)]
        ]

        let vdspFftResult = matrix.fft()
        for i in 0..<height {
            for j in 0..<width {
                XCTAssertEqual(vdspFftResult[i, j].real, expectedResult[i][j].0, accuracy: 0.001, "(\(i),\(j)) not equal")
                XCTAssertEqual(vdspFftResult[i, j].imaginary, expectedResult[i][j].1, accuracy: 0.001, "(\(i),\(j)) not equal")
            }
        }
    }
}


