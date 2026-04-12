import SwiftUI

// MODULES tab — per-effect cards with a colour-coded header, a big module
// number, and the sliders that drive each module's parameters.
struct ModulesView: View {
    @ObservedObject var audioEngine: VoiceChangerAudioEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(kicker: "Effect Modules", title: "MOD\nULES")

                moduleCard(
                    number: "01",
                    title: "REVERB",
                    accent: Theme.secondary,
                    content: AnyView(
                        LabeledSlider(
                            title: "Amount",
                            value: $audioEngine.reverbAmount,
                            range: 0.0...1.0,
                            unit: "%",
                            format: "%.0f",
                            multiplier: 100,
                            puckColor: Theme.secondary
                        )
                    )
                )

                moduleCard(
                    number: "02",
                    title: "TREMOLO",
                    accent: Theme.tertiary,
                    content: AnyView(
                        VStack(spacing: 16) {
                            LabeledSlider(
                                title: "Rate",
                                value: $audioEngine.tremoloRate,
                                range: 0.0...20.0,
                                unit: "HZ",
                                format: "%.1f",
                                puckColor: Theme.tertiary
                            )
                            LabeledSlider(
                                title: "Depth",
                                value: $audioEngine.tremoloDepth,
                                range: 0.0...1.0,
                                unit: "%",
                                format: "%.0f",
                                multiplier: 100,
                                puckColor: Theme.tertiary
                            )
                        }
                    )
                )

                moduleCard(
                    number: "03",
                    title: "RING MOD",
                    accent: Theme.primary,
                    content: AnyView(
                        VStack(spacing: 16) {
                            LabeledSlider(
                                title: "Rate",
                                value: $audioEngine.ringModRate,
                                range: 0.0...200.0,
                                unit: "HZ",
                                format: "%.0f",
                                puckColor: Theme.primary
                            )
                            LabeledSlider(
                                title: "Mix",
                                value: $audioEngine.ringModMix,
                                range: 0.0...1.0,
                                unit: "%",
                                format: "%.0f",
                                multiplier: 100,
                                puckColor: Theme.primary
                            )
                        }
                    )
                )

                moduleCard(
                    number: "04",
                    title: "PITCH",
                    accent: .black,
                    content: AnyView(
                        LabeledSlider(
                            title: "Semitones",
                            value: $audioEngine.pitchShift,
                            range: -12.0...12.0,
                            unit: "ST",
                            format: "%+.1f",
                            puckColor: .black
                        )
                    )
                )

                moduleCard(
                    number: "05",
                    title: "MASTER",
                    accent: Theme.secondary,
                    content: AnyView(
                        LabeledSlider(
                            title: "Volume",
                            value: $audioEngine.masterVolume,
                            range: 0.0...4.0,
                            unit: "X",
                            format: "%.2f",
                            puckColor: Theme.secondary
                        )
                    )
                )
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func moduleCard(number: String, title: String, accent: Color, content: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(number)
                    .font(Theme.headline(40))
                    .tracking(-2)
                    .foregroundColor(.white)
                Spacer()
                Text(title)
                    .font(Theme.label(14))
                    .foregroundColor(.white)
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(accent)

            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surfaceContainer)
        }
        .bauhausBorder()
        .bauhausShadow()
    }
}
