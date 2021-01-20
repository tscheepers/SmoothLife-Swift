import Foundation
import Accelerate

class SmoothLife {

    /// The field containing the current state
    var field: Matrix<Double>

    /// Also called b1 and b2
    let birthInterval: (Double, Double)

    /// Also called d1 and d2
    let deathInterval: (Double, Double)

    /// dt is the amount each step calculation should contribute to the next field.
    /// Used for smooth transitions in the time dimension
    let dt: Double

    /// Inner radius of the effective cell
    let innerRadius: Double

    /// Outer radius to the cells neightbors
    let outerRadius: Double

    /// Also called `N`
    /// The neightborhood kernel expressed in the frequency domain
    let neightborhoodKernel: Matrix<ComplexDouble>

    /// Also called `M`
    /// The effectiveCell kernel expressed in the frequency domain
    let effectiveCellKernel: Matrix<ComplexDouble>

    /// Easy accessor for the field's shape
    var shape: (height: Int, width: Int) {
        return field.shape
    }

    /// If you reuse a single FFTSetupD object for multiple transforms the code will be more performant
    let fftSetup: FFTSetupD

    init(
        shape: (height: Int, width: Int) = (64, 64),
        birthInterval: (Double, Double) = (0.254, 0.312),
        deathInterval: (Double, Double) = (0.340, 0.518),
        innerRadius: Double = 4.0,
        outerRadius: Double = 12.0,
        dt: Double = 0.1,
        field: Matrix<Double>? = nil
    ) {
        self.field = field ?? Self.randomField(radius: Int(outerRadius), shape: shape)
        self.fftSetup = self.field.createFftSetup()

        self.birthInterval = birthInterval
        self.deathInterval = deathInterval
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.dt = dt

        (self.effectiveCellKernel, self.neightborhoodKernel) = Self.kernels(shape: shape, innerRadius: innerRadius, outerRadius: outerRadius)
    }

    /// Reset the field and restart the simulation
    func reset() {
        self.field = Self.randomField(radius: Int(outerRadius), shape: shape)
    }

    /// Perform a step and update the field
    func step() {

        // Execute convolution in the frequency domain
        let (M, N) = self.applyKernels()

        // The new field
        let S = self.transition(M: M, N: N)

        // Update using smooth timesteps
        field = (field + dt * (S - field)).clamp()
    }

    /// Apply convolution by multiplying in the frequency domain
    func applyKernels() -> (M: Matrix<Double>, N: Matrix<Double>)
    {
        let fieldInFd = field.fft(reuseSetup: fftSetup)

        let effectiveCellKernelApplied = (fieldInFd * effectiveCellKernel).fft(.inverse, reuseSetup: fftSetup).real
        let neightborhoodKernelApplied = (fieldInFd * neightborhoodKernel).fft(.inverse, reuseSetup: fftSetup).real

        return (M: effectiveCellKernelApplied, N: neightborhoodKernelApplied)
    }

    /// Apply the transition function
    func transition(M: Matrix<Double>, N: Matrix<Double>) -> Matrix<Double>
    {
        func sigma(_ birth: Matrix<Double>, _ death: Matrix<Double>, _ M: Matrix<Double>) -> Matrix<Double> {
            return birth * (1.0 - M.hardStep()) + death * M.hardStep();
        }

        func sigmaInterval(_ N: Matrix<Double>, _ interval: (Double, Double)) -> Matrix<Double>
        {
            return N.hardStep(interval.0) * (1.0 - N.hardStep(interval.1));
        }

        return sigma(sigmaInterval(N, birthInterval), sigmaInterval(N, deathInterval), M)
    }

    /// Creates a shifted smooth cricle with extremes at the edges
    static func shiftedSmoothCircle(shape: (height: Int, width: Int), radius: Double = 12.0) -> Matrix<Double> {

        let (rowIncreading, colIncreasing) = Matrix<Double>.meshGrid(shape: shape)
        let (height, width) = (Double(shape.height), Double(shape.width))

        let radii = sqrt(pow(colIncreasing - height/2, power: 2) + pow(rowIncreading - width/2, power: 2))
        let logistic: Matrix<Double> = 1.0 / (1.0 + exp(log2(min(height, width)) * (radii - radius)))

        return logistic
            .roll(rows: shape.height/2)
            .roll(cols: shape.width/2)
    }

    /// Creates a field with random squares distributed onto it, this has been shown to be a good initialization method
    static func randomField(radius: Int, shape: (height: Int, width: Int)) -> Matrix<Double> {
        let n = Int(shape.height * shape.width)

        // The amount of cells being created here is similair to the original implementation. It seems to work well
        let cells: Int = n / (radius * radius * 4)
        return Self.field(fromUpperLeftCoords: (0..<cells).map({ _ in
            let r = (0..<shape.height - radius).randomElement()!
            let c = (0..<shape.width - radius).randomElement()!
            return (r, c)
        }), squareSize: radius, shape: shape)
    }

    /// Generate a field with squares at specific cords
    /// This method can be used to repeat certain initializations
    static func field(fromUpperLeftCoords upperLeftCoords: [(Int, Int)], squareSize: Int, shape: (height: Int, width: Int)) -> Matrix<Double> {
        var field = Matrix<Double>.zeros(shape: shape)
        for (r, c) in upperLeftCoords {
            for i in r..<r+squareSize {
                for j in c..<c+squareSize {
                    field[i,j] = 1.0
                }
            }
        }
        return field
    }

    /// Provides the required kernels in the frequency domain
    static func kernels(shape: (height: Int, width: Int), innerRadius: Double, outerRadius: Double) -> (Matrix<ComplexDouble>, Matrix<ComplexDouble>) {
        var effectiveCellKernel = self.shiftedSmoothCircle(shape: shape, radius: innerRadius)
        var neightborhoodKernel = self.shiftedSmoothCircle(shape: shape, radius: outerRadius) - effectiveCellKernel

        effectiveCellKernel = effectiveCellKernel / effectiveCellKernel.sum
        neightborhoodKernel = neightborhoodKernel / neightborhoodKernel.sum

        // We transform the kernels to the frequency domain
        return (effectiveCellKernel.fft(), neightborhoodKernel.fft())
    }

    deinit {
        vDSP_destroy_fftsetupD(self.fftSetup)
    }
}
