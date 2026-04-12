import SwiftUI

// EQUALIZER tab — three VerticalFader blocks tiled across the width.
// Each fader is a Bauhaus "big coloured block" holding the vertical slider.
struct EqualizerView: View {
    @ObservedObject var audioEngine: VoiceChangerAudioEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(kicker: "Tone Shaping", title: "EQUAL\nIZER")

                HStack(spacing: 12) {
                    VerticalFader(
                        title: "Bass",
                        subtitle: "80 HZ · LOW SHELF",
                        value: $audioEngine.bassGain,
                        range: -12.0...12.0,
                        background: Theme.tertiary
                    )
                    .frame(height: 360)
                    .bauhausBorder()

                    VerticalFader(
                        title: "Mid",
                        subtitle: "1 KHZ · PEAKING",
                        value: $audioEngine.midGain,
                        range: -12.0...12.0,
                        background: Color(red: 0xC7/255.0, green: 0xD6/255.0, blue: 0xEE/255.0)
                    )
                    .frame(height: 360)
                    .bauhausBorder()

                    VerticalFader(
                        title: "Treb",
                        subtitle: "8 KHZ · HI SHELF",
                        value: $audioEngine.trebleGain,
                        range: -12.0...12.0,
                        background: Color(red: 0xF3/255.0, green: 0xC4/255.0, blue: 0xCC/255.0)
                    )
                    .frame(height: 360)
                    .bauhausBorder()
                }

                HStack(spacing: 12) {
                    eqReadout(label: "BASS", value: audioEngine.bassGain)
                    eqReadout(label: "MID", value: audioEngine.midGain)
                    eqReadout(label: "TREB", value: audioEngine.trebleGain)
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func eqReadout(label: String, value: Float) -> some View {
        VStack(spacing: 4) {
            TagLabel(text: label, filled: .black)
            Text(String(format: "%+.1f dB", value))
                .font(Theme.label(14))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surfaceContainer)
        .bauhausBorder(Theme.thinBorderWidth)
    }
}
