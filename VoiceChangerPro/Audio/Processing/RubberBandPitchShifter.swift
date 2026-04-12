import Foundation

// Drop-in replacement for the in-house PhaseVocoder. Wraps Rubber Band
// (RubberBandBridge.mm) in a Swift surface identical to the old vocoder:
//   - init(sampleRate:)
//   - setPitchSemitones(_:)
//   - process(_:frameCount:)
//   - reset()
//
// Rubber Band is realtime-safe in its "Finer" (R3) realtime mode; setPitchScale
// is safe to call from a different thread than process(). pitchSemitones is a
// 4-byte Float mirror so we can throttle no-op updates.
final class RubberBandPitchShifter: @unchecked Sendable {
    private let handle: RBPitchShifterRef?
    private var pitchSemitones: Float = 0.0

    init(sampleRate: Double) {
        self.handle = rb_create(sampleRate)
    }

    deinit {
        if let h = handle { rb_destroy(h) }
    }

    func setPitchSemitones(_ semitones: Float) {
        guard let h = handle else { return }
        pitchSemitones = semitones
        rb_set_pitch_semitones(h, semitones)
    }

    func reset() {
        guard let h = handle else { return }
        rb_reset(h)
    }

    /// In-place pitch shift on a mono buffer. `frameCount` samples in → out.
    /// At pitchSemitones == 0 this is exact-bypass (zero library cost).
    func process(_ samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard let h = handle, frameCount > 0 else { return }
        if abs(pitchSemitones) < 0.01 { return }   // bypass
        rb_process(h, samples, Int32(frameCount))
    }
}
