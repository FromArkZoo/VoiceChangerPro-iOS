import SwiftUI

// PRESETS tab — scrollable list of the 6 character presets.
// Each row: numeric tag, glyph block, name + description, apply arrow.
// Tapping a row calls VoiceProcessor.applyPreset(...) which writes to
// AudioEngine's @Published fields and updates the whole signal chain.
struct PresetsView: View {
    @ObservedObject var audioEngine: VoiceChangerAudioEngine
    @ObservedObject var voiceProcessor: VoiceProcessor
    @ObservedObject var presetManager: PresetManager

    private struct PresetVisual {
        let symbol: String
        let color: Color
        let tagline: String
    }

    private let visuals: [String: PresetVisual] = [
        "Chipmunk":  .init(symbol: "hare.fill",              color: Theme.tertiary,  tagline: "+10 ST · SPARK TOP"),
        "Tiny":      .init(symbol: "circle.grid.3x3.fill",   color: Theme.secondary, tagline: "+12 ST · THIN"),
        "Giant":     .init(symbol: "mountain.2.fill",        color: .black,          tagline: "-12 ST · HEAVY"),
        "Dark Lord": .init(symbol: "flame.fill",             color: Theme.primary,   tagline: "-9 ST · SINISTER"),
        "Ghostly":   .init(symbol: "wind",                   color: Theme.secondary, tagline: "TREMOLO · SPACE"),
        "Robot":     .init(symbol: "gearshape.2.fill",       color: Theme.primary,   tagline: "RING MOD · METAL")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(kicker: "Voice Presets", title: "CHAR\nACTERS")

                VStack(spacing: 12) {
                    ForEach(Array(VoicePreset.presets.enumerated()), id: \.offset) { idx, preset in
                        row(index: idx, preset: preset)
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func row(index: Int, preset: VoicePreset) -> some View {
        let v = visuals[preset.name] ?? PresetVisual(symbol: "waveform", color: .black, tagline: "PRESET")
        let active = isActive(preset)

        return HStack(spacing: 0) {
                Text(String(format: "%02d", index + 1))
                    .font(Theme.headline(28))
                    .tracking(-1)
                    .foregroundColor(.black)
                    .frame(width: 72, height: 72)
                    .background(Theme.tertiary)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: Theme.thinBorderWidth))

                Image(systemName: v.symbol)
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 72, height: 72)
                    .background(v.color)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: Theme.thinBorderWidth))

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name.uppercased())
                        .font(Theme.headline(18))
                        .tracking(-0.5)
                        .foregroundColor(.black)
                    TagLabel(text: v.tagline)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: active ? "checkmark" : "arrow.right")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(active ? .white : .black)
                    .frame(width: 56, height: 72)
                    .background(active ? Theme.primary : Theme.surfaceContainer)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: Theme.thinBorderWidth))
            }
        .background(Theme.background)
        .bauhausBorder()
        .bauhausShadow()
        .contentShape(Rectangle())
        .onTapGesture { apply(preset: preset, index: index) }
    }

    private func apply(preset: VoicePreset, index: Int) {
        voiceProcessor.applyPreset(preset, to: audioEngine)
        presetManager.selectPreset(at: index)
    }

    private func isActive(_ preset: VoicePreset) -> Bool {
        let tol: Float = 0.001
        return abs(audioEngine.pitchShift - preset.pitch) < tol
            && abs(audioEngine.bassGain - preset.bass) < tol
            && abs(audioEngine.midGain - preset.mid) < tol
            && abs(audioEngine.trebleGain - preset.treble) < tol
            && abs(audioEngine.reverbAmount - preset.reverb) < tol
            && abs(audioEngine.ringModRate - preset.ringModRate) < tol
            && abs(audioEngine.ringModMix - preset.ringModMix) < tol
            && abs(audioEngine.tremoloRate - preset.tremoloRate) < tol
            && abs(audioEngine.tremoloDepth - preset.tremoloDepth) < tol
    }
}
