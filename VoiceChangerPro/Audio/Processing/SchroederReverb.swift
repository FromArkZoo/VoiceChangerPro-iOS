import Foundation

// Classic Schroeder reverb: 4 parallel comb filters into 2 series all-pass.
// Delay lengths are the Freeverb/Schroeder canonical primes (scaled from the
// 44.1k originals to our sample rate so tonality is roughly constant).
//
// Fixed room + damping defaults — the UI only exposes a single "Reverb" slider
// which we treat as wet/dry mix. Room size and damping can be lifted to the
// UI later; keeping them as constants here makes the plain "amount" slider
// feel like a sensible hall preset.
//
// Thread model: wetDryMix is a single 4-byte float updated from UI, read on
// audio thread — atomic per-word on arm64. All internal state lives in the
// filter objects and is only touched by process().
final class SchroederReverb {
    private let sampleRate: Double

    // Canonical Freeverb comb delays (in samples @ 44.1k). We scale to sr.
    private static let combDelays44k: [Int]   = [1116, 1188, 1277, 1356]
    private static let allpassDelays44k: [Int] = [556, 441]

    // Defaults tuned for "medium hall"-ish sound.
    private let roomSize: Float = 0.84   // comb feedback
    private let damping: Float = 0.2    // lowpass inside comb

    private var combs: [CombFilter] = []
    private var allpasses: [AllpassFilter] = []

    var wetDryMix: Float = 0.0   // 0 = dry, 1 = wet

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        let scale = sampleRate / 44100.0
        for d in Self.combDelays44k {
            let len = max(1, Int((Double(d) * scale).rounded()))
            combs.append(CombFilter(length: len, feedback: roomSize, damping: damping))
        }
        for d in Self.allpassDelays44k {
            let len = max(1, Int((Double(d) * scale).rounded()))
            allpasses.append(AllpassFilter(length: len, feedback: 0.5))
        }
    }

    func reset() {
        for c in combs { c.reset() }
        for a in allpasses { a.reset() }
    }

    // In-place wet/dry mix.
    func process(_ samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard frameCount > 0 else { return }
        let wet = wetDryMix
        if wet <= 0.0001 { return }   // fully dry — skip
        let dry = 1.0 - wet

        for i in 0..<frameCount {
            let x = samples[i]
            // Parallel combs summed.
            var y: Float = 0
            for c in combs { y += c.process(x) }
            // Series all-passes.
            for a in allpasses { y = a.process(y) }
            // Scale down the comb sum (4 parallel filters sum to a loud signal).
            y *= 0.25
            samples[i] = dry * x + wet * y
        }
    }
}

// MARK: - Comb filter with one-pole lowpass in the feedback path (Freeverb style).

private final class CombFilter {
    private var buffer: [Float]
    private var index: Int = 0
    private var lpState: Float = 0
    let feedback: Float
    let damping: Float

    init(length: Int, feedback: Float, damping: Float) {
        self.buffer = [Float](repeating: 0, count: length)
        self.feedback = feedback
        self.damping = damping
    }

    func reset() {
        for i in 0..<buffer.count { buffer[i] = 0 }
        lpState = 0
        index = 0
    }

    @inline(__always)
    func process(_ x: Float) -> Float {
        let out = buffer[index]
        // One-pole lowpass on the feedback tap: lpState = out*(1-d) + lpState*d
        lpState = out * (1.0 - damping) + lpState * damping
        buffer[index] = x + lpState * feedback
        index += 1
        if index >= buffer.count { index = 0 }
        return out
    }
}

// MARK: - Schroeder all-pass.

private final class AllpassFilter {
    private var buffer: [Float]
    private var index: Int = 0
    let feedback: Float

    init(length: Int, feedback: Float) {
        self.buffer = [Float](repeating: 0, count: length)
        self.feedback = feedback
    }

    func reset() {
        for i in 0..<buffer.count { buffer[i] = 0 }
        index = 0
    }

    @inline(__always)
    func process(_ x: Float) -> Float {
        let delayed = buffer[index]
        let y = -x + delayed
        buffer[index] = x + delayed * feedback
        index += 1
        if index >= buffer.count { index = 0 }
        return y
    }
}
