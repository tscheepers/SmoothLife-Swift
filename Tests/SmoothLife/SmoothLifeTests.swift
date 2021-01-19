import XCTest

    
class SmoothLifeTests: XCTestCase {

    func testFieldFromUpperLeftCords() throws {
        let field = SmoothLife.field(fromUpperLeftCoords: Fixtures.startStateCords, squareSize: 12, shape: (height: 64, width: 64))
        for i in 0..<64 {
            for j in 0..<64 {
                XCTAssertEqual(field[i, j], Fixtures.startState[i][j], "(\(i),\(j)) not equal")
            }
        }
    }

    func testShiftedSmoothCircle() throws {
        let field = SmoothLife.shiftedSmoothCircle(shape: (height: 64, width: 64), radius: 4.0)
        for i in 0..<64 {
            for j in 0..<64 {
                XCTAssertEqual(field[i, j], Fixtures.circleInnerRadius[i][j], accuracy: 0.001, "(\(i),\(j)) not equal")
            }
        }
    }

    func testKernelInFd() {
        let (effectiveCellKernel, _) = SmoothLife.kernels(shape: (height: 64, width: 64), innerRadius: 4.0, outerRadius: 12.0)
        let realEffectiveCellKernel = effectiveCellKernel.real

        for i in 0..<64 {
            for j in 0..<64 {
                XCTAssertEqual(realEffectiveCellKernel[i, j], Fixtures.effectiveCellKernelInFd[i][j], accuracy: 0.001, "(\(i),\(j)) not equal")
            }
        }
    }

    func testFieldFftComplex() {
        let field = SmoothLife.field(fromUpperLeftCoords: Fixtures.startStateCords, squareSize: 12, shape: (height: 64, width: 64))
        let fieldInFd = field.fft()

        for i in 0..<64 {
            for j in 0..<64 {
                XCTAssertEqual(fieldInFd[i, j].real, Fixtures.fftOnVirginField[i][j].real, accuracy: 0.001, "(\(i),\(j)) real not equal")
                XCTAssertEqual(fieldInFd[i, j].imaginary, Fixtures.fftOnVirginField[i][j].imaginary, accuracy: 0.001, "(\(i),\(j)) imaginary not equal")
            }
        }

        let fieldInTd = fieldInFd.fft(.inverse).real

        for i in 0..<64 {
            for j in 0..<64 {
                XCTAssertEqual(field[i, j], fieldInTd[i, j], accuracy: 0.001, "(\(i),\(j)) not equal")
            }
        }
    }

    func testMultiplicationInFd() {
        let field = SmoothLife.field(fromUpperLeftCoords: Fixtures.startStateCords, squareSize: 12, shape: (height: 64, width: 64))
        let smoothLife = SmoothLife(shape: (height: 64, width: 64), field: field)
        let (M, _) = smoothLife.applyKernels()

        for i in 0..<64 {
            for j in 0..<64 {
                XCTAssertEqual(M[i, j], Fixtures.effectiveCellKernelAppliedToField[i][j], accuracy: 0.001, "(\(i),\(j)) not equal")
            }
        }
    }

    func testTransitionFunction() {
        let field = SmoothLife.field(fromUpperLeftCoords: Fixtures.startStateCords, squareSize: 12, shape: (height: 64, width: 64))
        let smoothLife = SmoothLife(shape: (height: 64, width: 64), field: field)
        let (M, N) = smoothLife.applyKernels()
        let S = smoothLife.transition(M: M, N: N)

        for i in 0..<64 {
            for j in 0..<64 {
                XCTAssertEqual(S[i, j], Fixtures.transitionResult[i][j], accuracy: 0.001, "(\(i),\(j)) not equal")
            }
        }
    }
}
    

