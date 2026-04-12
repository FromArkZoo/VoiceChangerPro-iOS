import Foundation

// Direct Form I biquad with RBJ cookbook coefficients.
// Reference: Robert Bristow-Johnson, "Audio EQ Cookbook"
// https://www.w3.org/TR/audio-eq-cookbook/
//
// All three shapes used by the 3-band EQ bank (low-shelf, peaking, high-shelf)
// compute the same b0/b1/b2/a0/a1/a2 set; only the formulas for those
// coefficients differ. Gain is specified in dB, shelves/peaks share a shared
// shelf slope / Q parameter. Processing is in-place on a Float buffer and
// carries state across calls via z1/z2.
struct BiquadFilter {
    enum Shape {
        case lowShelf
        case peaking
        case highShelf
    }

    // Transfer function numerator / denominator, normalised so a0 = 1.
    private var b0: Float = 1
    private var b1: Float = 0
    private var b2: Float = 0
    private var a1: Float = 0
    private var a2: Float = 0

    // Direct Form I state.
    private var x1: Float = 0
    private var x2: Float = 0
    private var y1: Float = 0
    private var y2: Float = 0

    var coefficients: (b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) {
        (b0, b1, b2, a1, a2)
    }

    mutating func reset() {
        x1 = 0; x2 = 0; y1 = 0; y2 = 0
    }

    /// Configure the filter. `q` is the shelf slope S for shelves and the
    /// bandwidth Q for peaking. `gainDB` is ±dB (0 = flat).
    mutating func configure(shape: Shape, frequency: Float, gainDB: Float, q: Float, sampleRate: Float) {
        let w0 = 2 * Float.pi * frequency / sampleRate
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        let A = pow(10, gainDB / 40)  // amplitude, not power, per cookbook

        let b0u, b1u, b2u, a0u, a1u, a2u: Float
        switch shape {
        case .peaking:
            // Peaking EQ: Q-bandwidth form.
            let alpha = sinW0 / (2 * max(q, 0.01))
            b0u = 1 + alpha * A
            b1u = -2 * cosW0
            b2u = 1 - alpha * A
            a0u = 1 + alpha / A
            a1u = -2 * cosW0
            a2u = 1 - alpha / A

        case .lowShelf:
            // Low shelf: slope-S form. S=1 is the steepest setting without
            // peaking in the response.
            let S = max(min(q, 1.0), 0.01)
            let alpha = sinW0 / 2 * sqrt((A + 1 / A) * (1 / S - 1) + 2)
            let twoSqrtAalpha = 2 * sqrt(A) * alpha
            b0u = A * ((A + 1) - (A - 1) * cosW0 + twoSqrtAalpha)
            b1u = 2 * A * ((A - 1) - (A + 1) * cosW0)
            b2u = A * ((A + 1) - (A - 1) * cosW0 - twoSqrtAalpha)
            a0u = (A + 1) + (A - 1) * cosW0 + twoSqrtAalpha
            a1u = -2 * ((A - 1) + (A + 1) * cosW0)
            a2u = (A + 1) + (A - 1) * cosW0 - twoSqrtAalpha

        case .highShelf:
            let S = max(min(q, 1.0), 0.01)
            let alpha = sinW0 / 2 * sqrt((A + 1 / A) * (1 / S - 1) + 2)
            let twoSqrtAalpha = 2 * sqrt(A) * alpha
            b0u = A * ((A + 1) + (A - 1) * cosW0 + twoSqrtAalpha)
            b1u = -2 * A * ((A - 1) + (A + 1) * cosW0)
            b2u = A * ((A + 1) + (A - 1) * cosW0 - twoSqrtAalpha)
            a0u = (A + 1) - (A - 1) * cosW0 + twoSqrtAalpha
            a1u = 2 * ((A - 1) - (A + 1) * cosW0)
            a2u = (A + 1) - (A - 1) * cosW0 - twoSqrtAalpha
        }

        // Normalise so a0 = 1.
        let inv = 1 / a0u
        b0 = b0u * inv
        b1 = b1u * inv
        b2 = b2u * inv
        a1 = a1u * inv
        a2 = a2u * inv
    }

    /// In-place Direct Form I processing. Allocation-free.
    mutating func process(_ samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        var x1 = self.x1
        var x2 = self.x2
        var y1 = self.y1
        var y2 = self.y2
        let b0 = self.b0
        let b1 = self.b1
        let b2 = self.b2
        let a1 = self.a1
        let a2 = self.a2

        for i in 0..<frameCount {
            let x = samples[i]
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            samples[i] = y
        }

        self.x1 = x1
        self.x2 = x2
        self.y1 = y1
        self.y2 = y2
    }
}
