import Foundation

// Amplitude tremolo: y = x * (1 + depth * sin(2π·rate·t)).
// Unlike ring mod this is a slow LFO wobble — no audible sideband distortion,
// just volume modulation. Mono, in-place, allocation-free.
//
// `rateHz` — LFO frequency (typical 0.5–20 Hz).
// `depth`  — 0 = no modulation, 1 = full ±100% swing.
final class Tremolo: @unchecked Sendable {
    private let sampleRate: Double
    private var phase: Double = 0
    private var phaseInc: Double = 0

    var rateHz: Float = 0 { didSet {
        if oldValue != rateHz {
            phaseInc = 2.0 * .pi * Double(max(0, rateHz)) / sampleRate
            NSLog(String(format: "VCP-TREMOLO-RECOMPUTE rateHz=%.2f phaseInc=%.6f",
                         rateHz, phaseInc))
        }
    } }
    var depth: Float = 0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func reset() {
        phase = 0
    }

    func process(_ samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard frameCount > 0, depth > 0.001, rateHz > 0 else { return }
        let d = Double(depth)
        let twoPi = 2.0 * Double.pi
        var ph = phase
        let inc = phaseInc
        for i in 0..<frameCount {
            let lfo = 1.0 + d * sin(ph)
            samples[i] = Float(Double(samples[i]) * lfo)
            ph += inc
            if ph >= twoPi { ph -= twoPi }
        }
        phase = ph
    }
}
