import Foundation
import Accelerate
import AVFoundation

struct VoicePreset: Codable {
    let name: String
    let pitch: Float
    let formant: Float
    let timeStretch: Float
    let vocalTract: Float
    let bass: Float
    let mid: Float
    let treble: Float
    let reverb: Float

    static let presets = [
        VoicePreset(name: "Natural Male", pitch: 0, formant: 1.0, timeStretch: 1.0, vocalTract: 1.0, bass: 0, mid: 0, treble: 0, reverb: 0),
        VoicePreset(name: "Natural Female", pitch: 3, formant: 1.15, timeStretch: 1.0, vocalTract: 0.9, bass: 0, mid: 2, treble: 1, reverb: 0),
        VoicePreset(name: "Child Voice", pitch: 8, formant: 1.3, timeStretch: 1.1, vocalTract: 0.8, bass: -2, mid: 3, treble: 2, reverb: 0),
        VoicePreset(name: "Elderly Voice", pitch: -2, formant: 0.9, timeStretch: 0.95, vocalTract: 1.1, bass: 1, mid: -1, treble: -2, reverb: 0),
        VoicePreset(name: "Robot Voice", pitch: 0, formant: 0.7, timeStretch: 1.0, vocalTract: 1.2, bass: 2, mid: -3, treble: 4, reverb: 0.2),
        VoicePreset(name: "Alien Voice", pitch: 12, formant: 0.6, timeStretch: 1.2, vocalTract: 0.7, bass: -4, mid: 6, treble: 2, reverb: 0.4),
        VoicePreset(name: "Monster Voice", pitch: -8, formant: 0.5, timeStretch: 0.8, vocalTract: 1.5, bass: 6, mid: -2, treble: -4, reverb: 0.3)
    ]
}

/// Thread-safe circular buffer for audio analysis
private class ThreadSafeCircularBuffer {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private let size: Int
    private let lock = NSLock()

    init(size: Int) {
        self.size = size
        self.buffer = [Float](repeating: 0.0, count: size)
    }

    /// Append samples to the buffer (thread-safe)
    func append(_ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }

        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % size
        }
    }

    /// Get a copy of the most recent samples (thread-safe)
    func getRecentSamples(count: Int) -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        let requestedCount = min(count, size)
        var result = [Float](repeating: 0, count: requestedCount)

        // Calculate start index (going backwards from write position)
        var readIndex = (writeIndex - requestedCount + size) % size

        for i in 0..<requestedCount {
            result[i] = buffer[readIndex]
            readIndex = (readIndex + 1) % size
        }

        return result
    }

    /// Check if buffer has enough data
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return size  // Buffer is always "full" after initial fill
    }
}

class VoiceProcessor: ObservableObject {
    // Real-time analysis data
    @Published var fundamentalFrequency: Float = 0.0
    @Published var voiceActivity: Float = 0.0
    @Published var spectralCentroid: Float = 0.0

    // Thread-safe circular buffer for analysis
    private let analysisBuffer: ThreadSafeCircularBuffer
    private let analysisSize: Int
    private let hopSize: Int
    private var samplesReceived: Int = 0

    // Optimized FFT processor
    private var fftProcessor: OptimizedFFTProcessor

    init() {
        self.analysisSize = AudioConstants.analysisFFTLength
        self.hopSize = AudioConstants.hopSize
        self.analysisBuffer = ThreadSafeCircularBuffer(size: analysisSize)

        // Initialize optimized FFT processor
        fftProcessor = OptimizedFFTProcessor(fftLength: analysisSize)
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        // Append new data to thread-safe circular buffer
        let newData = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        analysisBuffer.append(newData)
        samplesReceived += frameCount

        // Perform analysis if we have enough data
        if samplesReceived >= analysisSize {
            performVoiceAnalysis()
        }
    }

    private func performVoiceAnalysis() {
        // Get samples from thread-safe buffer
        let samples = analysisBuffer.getRecentSamples(count: analysisSize)

        // Perform FFT using optimized processor (handles windowing internally)
        let spectrum = fftProcessor.processSpectrum(from: samples)

        // Calculate metrics
        let fundamentalFreq = estimateFundamentalFrequency(spectrum)
        let voiceAct = detectVoiceActivity(samples)
        let spectralCent = fftProcessor.calculateSpectralCentroid(from: spectrum, sampleRate: AudioConstants.analysisSampleRate)

        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            self?.fundamentalFrequency = fundamentalFreq
            self?.voiceActivity = voiceAct
            self?.spectralCentroid = spectralCent
        }
    }


    private func estimateFundamentalFrequency(_ spectrum: [Float]) -> Float {
        // Simple peak picking for fundamental frequency estimation
        guard spectrum.count > 0 else { return 0.0 }

        let sampleRate = AudioConstants.analysisSampleRate
        let minF0Bin = Int(AudioConstants.minFundamentalFrequency * Float(analysisSize) / sampleRate)
        let maxF0Bin = Int(AudioConstants.maxFundamentalFrequency * Float(analysisSize) / sampleRate)

        let searchRange = minF0Bin..<min(maxF0Bin, spectrum.count)
        guard !searchRange.isEmpty else { return 0.0 }

        let maxIndex = searchRange.max { spectrum[$0] < spectrum[$1] } ?? minF0Bin
        let frequency = Float(maxIndex) * sampleRate / Float(analysisSize)

        return frequency
    }

    private func detectVoiceActivity(_ buffer: [Float]) -> Float {
        // Simple energy-based voice activity detection
        var energy: Float = 0
        vDSP_rmsqv(buffer, 1, &energy, vDSP_Length(buffer.count))

        // Normalize and threshold
        let normalizedEnergy = min(1.0, energy * 10.0)
        return normalizedEnergy > 0.01 ? normalizedEnergy : 0.0
    }


    // MARK: - Advanced Processing Methods

    func applyFormantShifting(_ buffer: inout [Float], shiftAmount: Float) {
        // Simplified formant shifting using spectral envelope manipulation
        // In a full implementation, this would use more sophisticated algorithms
        // like linear predictive coding (LPC) or cepstral analysis

        let spectrum = fftProcessor.processSpectrum(from: buffer)
        var modifiedSpectrum = spectrum

        // Shift spectral envelope
        for i in 0..<modifiedSpectrum.count {
            let originalIndex = Float(i) / shiftAmount
            if originalIndex >= 0 && originalIndex < Float(spectrum.count - 1) {
                let index1 = Int(originalIndex)
                let index2 = min(index1 + 1, spectrum.count - 1)
                let fraction = originalIndex - Float(index1)

                modifiedSpectrum[i] = spectrum[index1] * (1.0 - fraction) + spectrum[index2] * fraction
            }
        }

        // Convert back to time domain
        if let inversed = fftProcessor.performInverseFFT(realPart: modifiedSpectrum, imagPart: [Float](repeating: 0, count: modifiedSpectrum.count)) {
            buffer = inversed
        }
    }


    func applyVocalTractLengthModification(_ buffer: inout [Float], lengthRatio: Float) {
        // Vocal tract length modification affects all formant frequencies uniformly
        // This is a simplified implementation using frequency domain shifting
        let spectrum = fftProcessor.processSpectrum(from: buffer)
        var modifiedSpectrum = [Float](repeating: 0.0, count: spectrum.count)

        for i in 0..<spectrum.count {
            let sourceIndex = Float(i) * lengthRatio
            if sourceIndex >= 0 && sourceIndex < Float(spectrum.count - 1) {
                let index1 = Int(sourceIndex)
                let index2 = min(index1 + 1, spectrum.count - 1)
                let fraction = sourceIndex - Float(index1)

                modifiedSpectrum[i] = spectrum[index1] * (1.0 - fraction) + spectrum[index2] * fraction
            }
        }

        if let inversed = fftProcessor.performInverseFFT(realPart: modifiedSpectrum, imagPart: [Float](repeating: 0, count: modifiedSpectrum.count)) {
            buffer = inversed
        }
    }

    func applyNoiseReduction(_ buffer: inout [Float], amount: Float) {
        // Spectral subtraction-based noise reduction
        let spectrum = fftProcessor.processSpectrum(from: buffer)
        var cleanSpectrum = spectrum

        // Estimate noise floor from quiet periods
        let noiseFloor = spectrum.min() ?? 0.0
        let threshold = noiseFloor + (1.0 - amount) * (spectrum.max() ?? 0.0 - noiseFloor)

        // Subtract noise
        for i in 0..<cleanSpectrum.count {
            if cleanSpectrum[i] < threshold {
                cleanSpectrum[i] *= amount
            }
        }

        if let inversed = fftProcessor.performInverseFFT(realPart: cleanSpectrum, imagPart: [Float](repeating: 0, count: cleanSpectrum.count)) {
            buffer = inversed
        }
    }

}

// MARK: - Preset Management

extension VoiceProcessor {
    func applyPreset(_ preset: VoicePreset, to audioEngine: VoiceChangerAudioEngine) {
        audioEngine.pitchShift = preset.pitch
        audioEngine.formantShift = preset.formant
        audioEngine.timeStretch = preset.timeStretch
        audioEngine.vocalTractLength = preset.vocalTract
        audioEngine.bassGain = preset.bass
        audioEngine.midGain = preset.mid
        audioEngine.trebleGain = preset.treble
        audioEngine.reverbAmount = preset.reverb
    }

    func createCustomPreset(from audioEngine: VoiceChangerAudioEngine, name: String) -> VoicePreset {
        return VoicePreset(
            name: name,
            pitch: audioEngine.pitchShift,
            formant: audioEngine.formantShift,
            timeStretch: audioEngine.timeStretch,
            vocalTract: audioEngine.vocalTractLength,
            bass: audioEngine.bassGain,
            mid: audioEngine.midGain,
            treble: audioEngine.trebleGain,
            reverb: audioEngine.reverbAmount
        )
    }
}