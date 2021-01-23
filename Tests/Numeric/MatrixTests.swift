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
}

func SLSAssertEqual<T>(_ matrix: Matrix<T>, _ list: [[T]]) where T : FloatingPoint {
    for i in 0..<matrix.height {
        for j in 0..<matrix.width {
            XCTAssertEqual(matrix[i, j], list[i][j], "(\(i),\(j)) not equal")
        }
    }
}


func SLSAssertEqual<T>(_ matrix: Matrix<T>, _ list: [[T]], accuracy: T) where T : FloatingPoint {
    for i in 0..<matrix.height {
        for j in 0..<matrix.width {
            XCTAssertEqual(matrix[i, j], list[i][j], accuracy: accuracy, "(\(i),\(j)) not equal")
        }
    }
}

func SLSAssertEqual<T>(_ matrixA: Matrix<T>, _ matrixB: Matrix<T>, accuracy: T) where T : FloatingPoint {
    for i in 0..<matrixA.height {
        for j in 0..<matrixA.width {
            XCTAssertEqual(matrixA[i, j], matrixB[i, j], accuracy: accuracy, "(\(i),\(j)) not equal")
        }
    }
}

func SLSAssertEqual<T>(_ matrixA: Matrix<Complex<T>>, _ matrixB: Matrix<Complex<T>>, accuracy: T) where T : FloatingPoint {
    for i in 0..<matrixA.height {
        for j in 0..<matrixA.width {
            XCTAssertEqual(matrixA[i, j].real, matrixB[i, j].real, accuracy: accuracy, "(\(i),\(j)) real not equal")
            XCTAssertEqual(matrixA[i, j].imaginary, matrixB[i, j].imaginary, accuracy: accuracy, "(\(i),\(j)) imaginary not equal")
        }
    }
}

func SLSAssertEqual<T>(_ matrix: Matrix<Complex<T>>, _ list: [[(T, T)]], accuracy: T) where T : FloatingPoint {
    for i in 0..<matrix.height {
        for j in 0..<matrix.width {
            XCTAssertEqual(matrix[i, j].real, list[i][j].0, accuracy: accuracy, "(\(i),\(j)) real not equal")
            XCTAssertEqual(matrix[i, j].imaginary, list[i][j].1, accuracy: accuracy, "(\(i),\(j)) imaginary not equal")
        }
    }
}

func SLSAssertEqual<T>(_ matrix: Matrix<Complex<T>>, _ list: [[Complex<T>]], accuracy: T) where T : FloatingPoint {
    for i in 0..<matrix.height {
        for j in 0..<matrix.width {
            XCTAssertEqual(matrix[i, j].real, list[i][j].real, accuracy: accuracy, "(\(i),\(j)) real not equal")
            XCTAssertEqual(matrix[i, j].imaginary, list[i][j].imaginary, accuracy: accuracy, "(\(i),\(j)) imaginary not equal")
        }
    }
}
