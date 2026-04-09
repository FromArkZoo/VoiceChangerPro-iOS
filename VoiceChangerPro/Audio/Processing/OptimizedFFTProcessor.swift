import Accelerate
import AVFoundation

/// Optimized FFT Processor with proper memory management and performance improvements
class OptimizedFFTProcessor {
    // MARK: - Properties
    private var fftSetup: FFTSetup?
    private var realBuffer: UnsafeMutablePointer<Float>
    private var imagBuffer: UnsafeMutablePointer<Float>
    private var windowBuffer: UnsafeMutablePointer<Float>
    private var splitComplex: DSPSplitComplex

    // Pre-allocated result buffers to avoid audio thread allocations
    private var windowedSamplesBuffer: UnsafeMutablePointer<Float>
    private var magnitudesBuffer: UnsafeMutablePointer<Float>
    private var logMagnitudesBuffer: UnsafeMutablePointer<Float>
    private var smoothedMagnitudesBuffer: UnsafeMutablePointer<Float>

    private let fftLength: Int
    private let log2n: vDSP_Length
    private let halfLength: Int

    // MARK: - Initialization
    init(fftLength: Int = 2048) {
        self.fftLength = fftLength
        self.halfLength = fftLength / 2
        self.log2n = vDSP_Length(log2(Float(fftLength)))

        // Properly allocate and manage memory
        self.realBuffer = UnsafeMutablePointer<Float>.allocate(capacity: halfLength)
        self.imagBuffer = UnsafeMutablePointer<Float>.allocate(capacity: halfLength)
        self.windowBuffer = UnsafeMutablePointer<Float>.allocate(capacity: fftLength)

        // Pre-allocate result buffers to avoid audio thread allocations
        self.windowedSamplesBuffer = UnsafeMutablePointer<Float>.allocate(capacity: fftLength)
        self.magnitudesBuffer = UnsafeMutablePointer<Float>.allocate(capacity: halfLength)
        self.logMagnitudesBuffer = UnsafeMutablePointer<Float>.allocate(capacity: halfLength)
        self.smoothedMagnitudesBuffer = UnsafeMutablePointer<Float>.allocate(capacity: halfLength)

        // Initialize buffers with zeros
        realBuffer.initialize(repeating: 0, count: halfLength)
        imagBuffer.initialize(repeating: 0, count: halfLength)
        windowBuffer.initialize(repeating: 0, count: fftLength)
        windowedSamplesBuffer.initialize(repeating: 0, count: fftLength)
        magnitudesBuffer.initialize(repeating: 0, count: halfLength)
        logMagnitudesBuffer.initialize(repeating: 0, count: halfLength)
        smoothedMagnitudesBuffer.initialize(repeating: 0, count: halfLength)

        // Create split complex structure
        self.splitComplex = DSPSplitComplex(realp: realBuffer, imagp: imagBuffer)

        // Create FFT setup
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        // Pre-calculate window function
        setupWindowFunction()
    }

    deinit {
        // Proper cleanup to prevent memory leaks
        realBuffer.deinitialize(count: halfLength)
        imagBuffer.deinitialize(count: halfLength)
        windowBuffer.deinitialize(count: fftLength)
        windowedSamplesBuffer.deinitialize(count: fftLength)
        magnitudesBuffer.deinitialize(count: halfLength)
        logMagnitudesBuffer.deinitialize(count: halfLength)
        smoothedMagnitudesBuffer.deinitialize(count: halfLength)

        realBuffer.deallocate()
        imagBuffer.deallocate()
        windowBuffer.deallocate()
        windowedSamplesBuffer.deallocate()
        magnitudesBuffer.deallocate()
        logMagnitudesBuffer.deallocate()
        smoothedMagnitudesBuffer.deallocate()

        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }

    // MARK: - Setup Methods
    private func setupWindowFunction() {
        // Use Hann window for better frequency resolution
        vDSP_hann_window(windowBuffer, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))
    }

    // MARK: - Processing Methods

    /// Process audio samples and return magnitude spectrum in dB
    /// Uses pre-allocated buffers to avoid allocations on audio thread
    func processSpectrum(from samples: [Float]) -> [Float] {
        guard let fftSetup = fftSetup else { return [] }

        // Ensure we have enough samples
        let processLength = min(samples.count, fftLength)
        if processLength < fftLength {
            return []
        }

        // Apply window function using pre-allocated buffer
        samples.withUnsafeBufferPointer { samplesPtr in
            guard let baseAddress = samplesPtr.baseAddress else { return }
            vDSP_vmul(baseAddress, 1,
                     windowBuffer, 1,
                     windowedSamplesBuffer, 1,
                     vDSP_Length(processLength))
        }

        // Clear buffers using update (not initialize - buffers already initialized)
        vDSP_vclr(realBuffer, 1, vDSP_Length(halfLength))
        vDSP_vclr(imagBuffer, 1, vDSP_Length(halfLength))

        // Convert to split complex format
        windowedSamplesBuffer.withMemoryRebound(to: DSPComplex.self, capacity: halfLength) { complexPtr in
            vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfLength))
        }

        // Perform FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Calculate magnitude spectrum using pre-allocated buffer
        vDSP_zvmags(&splitComplex, 1, magnitudesBuffer, 1, vDSP_Length(halfLength))

        // Convert to dB scale with reference level
        var reference: Float = 1.0
        vDSP_vdbcon(magnitudesBuffer, 1, &reference, logMagnitudesBuffer, 1, vDSP_Length(halfLength), 1)

        // Apply smoothing to reduce noise
        var smoothingFactor: Float = 0.8
        vDSP_vsmul(logMagnitudesBuffer, 1, &smoothingFactor, smoothedMagnitudesBuffer, 1, vDSP_Length(halfLength))

        // Return copy of results (caller can handle this allocation off audio thread)
        return Array(UnsafeBufferPointer(start: smoothedMagnitudesBuffer, count: halfLength))
    }

    /// Process spectrum with custom bin resolution
    func processSpectrumWithBins(from samples: [Float], binCount: Int = 256) -> [Float] {
        let fullSpectrum = processSpectrum(from: samples)
        guard !fullSpectrum.isEmpty else { return [] }

        // Downsample to desired bin count
        let binSize = halfLength / binCount
        var binnedSpectrum = [Float](repeating: 0, count: binCount)

        for i in 0..<binCount {
            let startBin = i * binSize
            let endBin = min((i + 1) * binSize, halfLength)

            if startBin < endBin && endBin <= fullSpectrum.count {
                // Get maximum value in bin range
                var maxValue: Float = 0
                let range = fullSpectrum[startBin..<endBin]
                vDSP_maxv(Array(range), 1, &maxValue, vDSP_Length(range.count))
                binnedSpectrum[i] = maxValue
            }
        }

        return binnedSpectrum
    }

    /// Calculate spectral centroid (brightness indicator)
    func calculateSpectralCentroid(from magnitudes: [Float], sampleRate: Float) -> Float {
        let nyquist = sampleRate / 2
        let binWidth = nyquist / Float(magnitudes.count)

        var weightedSum: Float = 0
        var magnitudeSum: Float = 0

        for (index, magnitude) in magnitudes.enumerated() {
            let frequency = Float(index) * binWidth
            let linearMagnitude = pow(10, magnitude / 20)  // Convert from dB
            weightedSum += frequency * linearMagnitude
            magnitudeSum += linearMagnitude
        }

        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0
    }

    /// Calculate spectral rolloff (frequency below which 85% of energy is contained)
    func calculateSpectralRolloff(from magnitudes: [Float], sampleRate: Float, threshold: Float = 0.85) -> Float {
        let nyquist = sampleRate / 2
        let binWidth = nyquist / Float(magnitudes.count)

        // Convert from dB to linear scale and calculate cumulative sum
        let linearMagnitudes = magnitudes.map { pow(10, $0 / 20) }
        var totalEnergy: Float = 0
        vDSP_sve(linearMagnitudes, 1, &totalEnergy, vDSP_Length(linearMagnitudes.count))

        let targetEnergy = totalEnergy * threshold
        var cumulativeEnergy: Float = 0

        for (index, magnitude) in linearMagnitudes.enumerated() {
            cumulativeEnergy += magnitude
            if cumulativeEnergy >= targetEnergy {
                return Float(index) * binWidth
            }
        }

        return nyquist
    }

    /// Perform inverse FFT for synthesis
    func performInverseFFT(realPart: [Float], imagPart: [Float]) -> [Float]? {
        guard let fftSetup = fftSetup,
              realPart.count == halfLength,
              imagPart.count == halfLength else {
            return nil
        }

        // Copy input to buffers using memory copy (buffers already initialized)
        realPart.withUnsafeBufferPointer { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            realBuffer.update(from: baseAddress, count: halfLength)
        }

        imagPart.withUnsafeBufferPointer { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            imagBuffer.update(from: baseAddress, count: halfLength)
        }

        // Perform inverse FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_INVERSE))

        // Convert back to interleaved complex format using pre-allocated buffer
        windowedSamplesBuffer.withMemoryRebound(to: DSPComplex.self, capacity: halfLength) { complexPtr in
            vDSP_ztoc(&splitComplex, 1, complexPtr, 2, vDSP_Length(halfLength))
        }

        // Scale by 1/N for proper inverse
        var scale = Float(1.0 / Float(fftLength))
        var scaledOutput = [Float](repeating: 0, count: fftLength)
        vDSP_vsmul(windowedSamplesBuffer, 1, &scale, &scaledOutput, 1, vDSP_Length(fftLength))

        return scaledOutput
    }
}

// MARK: - FFT Processor Extensions
extension OptimizedFFTProcessor {

    /// Analyze harmonic content of the signal
    func analyzeHarmonics(from spectrum: [Float], fundamentalFreq: Float, sampleRate: Float) -> [Float] {
        let binWidth = (sampleRate / 2) / Float(spectrum.count)
        var harmonicAmplitudes = [Float]()

        for harmonic in 1...10 {  // Analyze first 10 harmonics
            let harmonicFreq = fundamentalFreq * Float(harmonic)
            let binIndex = Int(harmonicFreq / binWidth)

            if binIndex < spectrum.count {
                harmonicAmplitudes.append(spectrum[binIndex])
            } else {
                harmonicAmplitudes.append(-100)  // Below noise floor
            }
        }

        return harmonicAmplitudes
    }

    /// Calculate spectral flux (measure of spectral change)
    func calculateSpectralFlux(current: [Float], previous: [Float]) -> Float {
        guard current.count == previous.count else { return 0 }

        var flux: Float = 0
        for i in 0..<current.count {
            let diff = current[i] - previous[i]
            if diff > 0 {  // Only consider positive differences
                flux += diff * diff
            }
        }

        return sqrt(flux)
    }
}
