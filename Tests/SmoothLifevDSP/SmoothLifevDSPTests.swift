import XCTest

    
class SmoothLifevDSPTests: XCTestCase {

    func testFieldFromUpperLeftCords() throws {
        let field = SmoothLifevDSP.field(fromUpperLeftCoords: Fixtures.startStateCords, squareSize: 12, shape: (height: 64, width: 64))
        SLSAssertEqual(field, Fixtures.startState)
    }

    func testShiftedSmoothCircle() throws {
        let field = SmoothLifevDSP.shiftedSmoothCircle(shape: (height: 64, width: 64), radius: 4.0)
        SLSAssertEqual(field, Fixtures.circleInnerRadius, accuracy: 0.001)
    }

    func testKernelInFd() {
        let (effectiveCellKernel, _) = SmoothLifevDSP.kernels(shape: (height: 64, width: 64), innerRadius: 4.0, outerRadius: 12.0)
        let realEffectiveCellKernel = effectiveCellKernel.real
        SLSAssertEqual(realEffectiveCellKernel, Fixtures.effectiveCellKernelInFd, accuracy: 0.001)
    }

    func testFieldFftComplex() {
        let field = SmoothLifevDSP.field(fromUpperLeftCoords: Fixtures.startStateCords, squareSize: 12, shape: (height: 64, width: 64))
        let fieldInFd = field.fft()
        SLSAssertEqual(fieldInFd, Fixtures.fftOnVirginField, accuracy: 0.001)

        let fieldInTd = fieldInFd.fft(.inverse).real
        SLSAssertEqual(field, fieldInTd, accuracy: 0.001)
    }

    func testMultiplicationInFd() {
        let field = SmoothLifevDSP.field(fromUpperLeftCoords: Fixtures.startStateCords, squareSize: 12, shape: (height: 64, width: 64))
        let smoothLife = SmoothLifevDSP(shape: (height: 64, width: 64), field: field)
        let (M, _) = smoothLife.applyKernels()
        SLSAssertEqual(M, Fixtures.effectiveCellKernelAppliedToField, accuracy: 0.001)
    }

    func testTransitionFunction() {
        let field = SmoothLifevDSP.field(fromUpperLeftCoords: Fixtures.startStateCords, squareSize: 12, shape: (height: 64, width: 64))
        let smoothLife = SmoothLifevDSP(shape: (height: 64, width: 64), field: field)
        let (M, N) = smoothLife.applyKernels()
        let S = smoothLife.transition(M: M, N: N)
        SLSAssertEqual(S, Fixtures.transitionResult, accuracy: 0.001)
    }
}
    

