import Foundation

// Owns the in-place DSP modules run inside the SourceNode render block.
// `process(_:frameCount:)` is called on the audio thread and must stay
// allocation-free. Parameter setters are called from the UI/main thread;
// a single aligned 4-byte write on arm64/x86_64 is atomic for our purposes
// — worst case a sample block uses slightly stale coefficients for one tick
// while the filter reconfigures.
final class DSPChain: @unchecked Sendable {
    let sampleRate: Double

    var pitchShiftSemitones: Float = 0.0 { didSet {
        if oldValue != pitchShiftSemitones {
            NSLog("VCP-PITCH-SET semitones=\(String(format: "%.2f", pitchShiftSemitones))")
            pitchVocoder.setPitchSemitones(pitchShiftSemitones)
            let ratio = pow(2.0, Double(pitchShiftSemitones) / 12.0)
            NSLog(String(format: "VCP-PITCH-RECOMPUTE semitones=%.2f ratio=%.4f stretch=%.4f",
                         pitchShiftSemitones, ratio, 1.0 / ratio))
        }
    } }
    var timeStretch: Float = 1.0
    var formantShift: Float = 1.0
    var vocalTractLength: Float = 1.0
    var noiseReduction: Float = 0.0

    var bassGain: Float = 0.0   { didSet {
        if oldValue != bassGain {
            NSLog("VCP-EQ-SET bass=\(String(format: "%.2f", bassGain))")
            recomputeEQ()
        }
    } }
    var midGain: Float = 0.0    { didSet {
        if oldValue != midGain {
            NSLog("VCP-EQ-SET mid=\(String(format: "%.2f", midGain))")
            recomputeEQ()
        }
    } }
    var trebleGain: Float = 0.0 { didSet {
        if oldValue != trebleGain {
            NSLog("VCP-EQ-SET treble=\(String(format: "%.2f", trebleGain))")
            recomputeEQ()
        }
    } }

    var reverbAmount: Float = 0.0 { didSet {
        if oldValue != reverbAmount {
            NSLog("VCP-REVERB-SET amount=\(String(format: "%.2f", reverbAmount))")
            reverb.wetDryMix = reverbAmount
            NSLog(String(format: "VCP-REVERB-RECOMPUTE amount=%.2f wet=%.2f dry=%.2f",
                         reverbAmount, reverbAmount, 1.0 - reverbAmount))
        }
    } }
    var bitDepth: Float = 16.0

    private var bassFilter = BiquadFilter()
    private var midFilter = BiquadFilter()
    private var trebleFilter = BiquadFilter()
    private let pitchVocoder: RubberBandPitchShifter
    private let reverb: SchroederReverb

    // Low-shelf pivot, one mid peaking band, high-shelf pivot —
    // matches the UI's three dB sliders.
    private let bassFrequency: Float = 100
    private let midFrequency: Float = 1_000
    private let trebleFrequency: Float = 8_000
    private let shelfSlope: Float = 0.7
    private let midQ: Float = 0.9

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        self.pitchVocoder = RubberBandPitchShifter(sampleRate: sampleRate)
        self.reverb = SchroederReverb(sampleRate: sampleRate)
        recomputeEQ()
    }

    func reset() {
        bassFilter.reset()
        midFilter.reset()
        trebleFilter.reset()
        pitchVocoder.reset()
        reverb.reset()
    }

    func process(_ samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard frameCount > 0 else { return }
        // Pitch shift first so downstream EQ operates on the shifted spectrum —
        // the typical mastering order, and what the user expects when they
        // notch a freq and then transpose.
        pitchVocoder.process(samples, frameCount: frameCount)
        if bassGain != 0 { bassFilter.process(samples, frameCount: frameCount) }
        if midGain != 0 { midFilter.process(samples, frameCount: frameCount) }
        if trebleGain != 0 { trebleFilter.process(samples, frameCount: frameCount) }
        // Reverb last so the tail is coloured by the upstream spectrum.
        if reverbAmount > 0 { reverb.process(samples, frameCount: frameCount) }
    }

    private func recomputeEQ() {
        let sr = Float(sampleRate)
        bassFilter.configure(shape: .lowShelf, frequency: bassFrequency,
                             gainDB: bassGain, q: shelfSlope, sampleRate: sr)
        midFilter.configure(shape: .peaking, frequency: midFrequency,
                            gainDB: midGain, q: midQ, sampleRate: sr)
        trebleFilter.configure(shape: .highShelf, frequency: trebleFrequency,
                               gainDB: trebleGain, q: shelfSlope, sampleRate: sr)
        let bc = bassFilter.coefficients
        let mc = midFilter.coefficients
        let tc = trebleFilter.coefficients
        NSLog(String(format: "VCP-EQ-RECOMPUTE bass=%.2f mid=%.2f treble=%.2f | bassCoeffs b0=%.4f b1=%.4f b2=%.4f a1=%.4f a2=%.4f | midCoeffs b0=%.4f b1=%.4f b2=%.4f a1=%.4f a2=%.4f | trebleCoeffs b0=%.4f b1=%.4f b2=%.4f a1=%.4f a2=%.4f",
                     bassGain, midGain, trebleGain,
                     bc.b0, bc.b1, bc.b2, bc.a1, bc.a2,
                     mc.b0, mc.b1, mc.b2, mc.a1, mc.a2,
                     tc.b0, tc.b1, tc.b2, tc.a1, tc.a2))
    }
}
