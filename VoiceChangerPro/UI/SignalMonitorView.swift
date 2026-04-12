import SwiftUI

// Bar-graph signal monitor used as the CONTROL tab hero strip.
// Heights animate off audioEngine.inputLevel + outputLevel so the bars feel
// alive without a full spectrum analyzer. 11 bars: alternating colours match
// the mockup (primary red, one black accent, secondary blue tail).
struct SignalMonitorView: View {
    @ObservedObject var audioEngine: VoiceChangerAudioEngine
    @State private var seed: Double = 0
    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    private let barColors: [Color] = [
        Theme.primary, Theme.primary, Theme.primary, Theme.primary,
        .black,
        Theme.primary, Theme.primary, Theme.primary,
        Theme.secondary, Theme.secondary,
        Theme.primary
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<barColors.count, id: \.self) { i in
                Rectangle()
                    .fill(barColors[i])
                    .frame(width: 16, height: barHeight(index: i))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 96)
        .onReceive(timer) { _ in
            seed += 1
        }
    }

    private func barHeight(index: Int) -> CGFloat {
        // Drive heights from a smoothed mix of live signal + a per-bar phase
        // offset so idle state still looks kinetic.
        let level = max(audioEngine.inputLevel, audioEngine.outputLevel * 0.9)
        let base = CGFloat(level) * 80 + 8
        let wobble = sin(seed * 0.6 + Double(index) * 1.1) * 14
        let h = base + CGFloat(wobble)
        return max(8, min(96, h))
    }
}
