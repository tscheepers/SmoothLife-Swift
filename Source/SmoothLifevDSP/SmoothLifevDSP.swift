import Foundation
import Accelerate
import Metal

class SmoothLifevDSP {

    /// The field containing the current state
    var field: Matrix<Float>

    /// Also called b1 and b2
    let birthInterval: (Float, Float)

    /// Also called d1 and d2
    let deathInterval: (Float, Float)

    /// dt is the amount each step calculation should contribute to the next field.
    /// Used for smooth transitions in the time dimension
    let dt: Float

    /// Inner radius of the effective cell
    let innerRadius: Float

    /// Outer radius to the cells neightbors
    let outerRadius: Float

    /// Also called `N`
    /// The neightborhood kernel expressed in the frequency domain
    let neightborhoodKernel: Matrix<Complex<Float>>

    /// Also called `M`
    /// The effectiveCell kernel expressed in the frequency domain
    let effectiveCellKernel: Matrix<Complex<Float>>

    /// Easy accessor for the field's shape
    var shape: (height: Int, width: Int) {
        return field.shape
    }

    /// If you reuse a single FFTSetup object for multiple transforms the code will be more performant
    let fftSetup: FFTSetup

    /// Texture to render the field onto
    let texture: MTLTexture

    init(
        shape: (height: Int, width: Int) = (64, 64),
        birthInterval: (Float, Float) = (0.254, 0.312),
        deathInterval: (Float, Float) = (0.340, 0.518),
        innerRadius: Float = 4.0,
        outerRadius: Float = 12.0,
        dt: Float = 0.1,
        field: Matrix<Float>? = nil,
        device: MTLDevice = MTLCreateSystemDefaultDevice()!
    ) {
        self.field = field ?? Self.randomField(radius: Int(outerRadius), shape: shape)
        self.fftSetup = self.field.createVdspFftSetup()

        self.birthInterval = birthInterval
        self.deathInterval = deathInterval
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.dt = dt

        (self.effectiveCellKernel, self.neightborhoodKernel) = Self.kernels(shape: shape, innerRadius: innerRadius, outerRadius: outerRadius)

        self.texture = device.makeTexture(descriptor: SLSTextureDescriptor(shape: shape))!
    }

    /// Reset the field and restart the simulation
    func reset() {
        self.field = Self.randomField(radius: Int(outerRadius), shape: shape)
    }

    /// Perform a step and update the field
    func step() -> Matrix<Float> {

        // Execute convolution in the frequency domain
        let (M, N) = self.applyKernels()

        // The new field
        let S = self.transition(M: M, N: N)

        // Update using smooth timesteps
        field = (field + dt * (S - field)).clamp()

        return field
    }

    /// Apply convolution by multiplying in the frequency domain
    func applyKernels() -> (M: Matrix<Float>, N: Matrix<Float>)
    {
        let fieldInFd = field.vdspFft(reuseSetup: fftSetup)

        let effectiveCellKernelApplied = (fieldInFd * effectiveCellKernel).vdspFft(.inverse, reuseSetup: fftSetup).real
        let neightborhoodKernelApplied = (fieldInFd * neightborhoodKernel).vdspFft(.inverse, reuseSetup: fftSetup).real

        return (M: effectiveCellKernelApplied, N: neightborhoodKernelApplied)
    }

    /// Apply the transition function
    func transition(M: Matrix<Float>, N: Matrix<Float>) -> Matrix<Float>
    {
        func sigma(_ birth: Matrix<Float>, _ death: Matrix<Float>, _ M: Matrix<Float>) -> Matrix<Float> {
            return birth * (1.0 - M.hardStep()) + death * M.hardStep();
        }

        func sigmaInterval(_ N: Matrix<Float>, _ interval: (Float, Float)) -> Matrix<Float>
        {
            return N.hardStep(interval.0) * (1.0 - N.hardStep(interval.1));
        }

        return sigma(sigmaInterval(N, birthInterval), sigmaInterval(N, deathInterval), M)
    }

    /// Creates a shifted smooth cricle with extremes at the edges
    static func shiftedSmoothCircle(shape: (height: Int, width: Int), radius: Float = 12.0) -> Matrix<Float> {

        let (rowIncreading, colIncreasing) = Matrix<Double>.meshGrid(shape: shape)
        let (height, width) = (Double(shape.height), Double(shape.width))

        let radii = sqrt(pow(colIncreasing - height/2, power: 2) + pow(rowIncreading - width/2, power: 2))

        // In this method we will calculate with Doubles because this calculation will otherwise overflow
        let logistic: Matrix<Double> = 1.0 / (1.0 + exp(log2(min(height, width)) * (radii - Double(radius))))

        return logistic
            .roll(rows: shape.height/2)
            .roll(cols: shape.width/2)
            .map { Float($0) }
    }

    /// Creates a field with random squares distributed onto it, this has been shown to be a good initialization method
    static func randomField(radius: Int, shape: (height: Int, width: Int)) -> Matrix<Float> {
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
    static func field(fromUpperLeftCoords upperLeftCoords: [(Int, Int)], squareSize: Int, shape: (height: Int, width: Int)) -> Matrix<Float> {
        var field = Matrix<Float>.zeros(shape: shape)
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
    static func kernels(shape: (height: Int, width: Int), innerRadius: Float, outerRadius: Float) -> (Matrix<Complex<Float>>, Matrix<Complex<Float>>) {
        var effectiveCellKernel = self.shiftedSmoothCircle(shape: shape, radius: innerRadius)
        var neightborhoodKernel = self.shiftedSmoothCircle(shape: shape, radius: outerRadius) - effectiveCellKernel

        effectiveCellKernel = effectiveCellKernel / effectiveCellKernel.sum
        neightborhoodKernel = neightborhoodKernel / neightborhoodKernel.sum

        // We transform the kernels to the frequency domain
        return (effectiveCellKernel.vdspFft(), neightborhoodKernel.vdspFft())
    }

    deinit {
        vDSP_destroy_fftsetup(self.fftSetup)
    }
}

extension SmoothLifevDSP : Life {

    var device: MTLDevice {
        return texture.device
    }

    func texture(forPresentationBy lifeRenderer: LifeRenderer) -> MTLTexture {
        return texture
    }

    func lifeRenderer(_ renderer: LifeRenderer, isQueueingCommandsOnBuffer commandBuffer: MTLCommandBuffer) {
        let result = step()
        result.fill(texture: texture)
    }
}
