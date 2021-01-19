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


