import Foundation

// Ring modulator: multiplies the input by a sine carrier. Produces the
// classic metallic "robot" timbre. Mono, in-place, allocation-free.
//
// `rateHz` — carrier frequency (phase accumulator, no lookup table).
// `mix`    — 0 = dry, 1 = fully modulated. Below ~0.001 we hard-bypass so
//            non-robot presets pay zero CPU.
final class RingModulator: @unchecked Sendable {
    private let sampleRate: Double
    private var phase: Double = 0
    private var phaseInc: Double = 0

    var rateHz: Float = 0 { didSet {
        if oldValue != rateHz {
            phaseInc = 2.0 * .pi * Double(max(0, rateHz)) / sampleRate
            NSLog(String(format: "VCP-RINGMOD-RECOMPUTE rateHz=%.2f phaseInc=%.6f",
                         rateHz, phaseInc))
        }
    } }
    var mix: Float = 0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func reset() {
        phase = 0
    }

    func process(_ samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard frameCount > 0, mix > 0.001, rateHz > 0 else { return }
        let m = Double(mix)
        let oneMinusM = 1.0 - m
        let twoPi = 2.0 * Double.pi
        var ph = phase
        let inc = phaseInc
        for i in 0..<frameCount {
            let s = Double(samples[i])
            let carrier = sin(ph)
            samples[i] = Float(s * oneMinusM + s * carrier * m)
            ph += inc
            if ph >= twoPi { ph -= twoPi }
        }
        phase = ph
    }
}
