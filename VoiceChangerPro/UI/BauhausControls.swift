import SwiftUI

// Horizontal slider in the mockup style: thick black rail, square puck with
// 4px black border. Uses a continuous drag gesture so the thumb can't pop.
struct BauhausSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    var puckColor: Color = Theme.primary

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 16)
                Rectangle()
                    .fill(puckColor)
                    .frame(width: 32, height: 32)
                    .bauhausBorder()
                    .offset(x: puckOffset(in: geo.size.width))
            }
            .frame(height: 32)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gv in
                        let w = geo.size.width - 32
                        let clamped = max(0, min(w, gv.location.x - 16))
                        let frac = Float(clamped / max(1, w))
                        value = range.lowerBound + frac * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: 32)
    }

    private func puckOffset(in total: CGFloat) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        let frac = span > 0 ? (value - range.lowerBound) / span : 0
        return CGFloat(frac) * (total - 32)
    }
}

// A labelled slider row used in Modules cards.
struct LabeledSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let unit: String
    let format: String
    var multiplier: Float = 1.0
    var puckColor: Color = Theme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TagLabel(text: title)
                Spacer()
                Text(String(format: format, value * multiplier) + " " + unit)
                    .font(Theme.label(14))
                    .foregroundColor(.black)
            }
            BauhausSlider(value: $value, range: range, puckColor: puckColor)
        }
    }
}

// Vertical fader used on the Equalizer tab — the white box inside a black rail
// shows the current gain in dB, per-band coloured background.
struct VerticalFader: View {
    let title: String
    let subtitle: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let background: Color

    var body: some View {
        VStack(spacing: 12) {
            Text(title.uppercased())
                .font(Theme.headline(40))
                .tracking(-1)
                .foregroundColor(.black.opacity(0.18))
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.black).frame(height: 4)
                        Spacer(minLength: 0)
                        Rectangle().fill(Color.black).frame(height: 4)
                    }

                    // Readout block that moves with the value
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geo.size.width, height: 64)
                        .overlay(
                            Text(String(format: "%+.1f", value))
                                .font(Theme.label(22))
                                .foregroundColor(.black)
                        )
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                        .bauhausShadow(Theme.shadowOffset)
                        .offset(y: knobOffset(in: geo.size.height))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gv in
                            let total = geo.size.height - 64
                            let y = max(0, min(total, gv.location.y - 32))
                            let frac = 1 - Float(y / max(1, total))
                            value = range.lowerBound + frac * (range.upperBound - range.lowerBound)
                        }
                )
            }

            Text(subtitle.uppercased())
                .font(Theme.label(10))
                .tracking(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.black)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }

    private func knobOffset(in total: CGFloat) -> CGFloat {
        let span = range.upperBound - range.lowerBound
        let frac = span > 0 ? (value - range.lowerBound) / span : 0
        let available = total - 64
        return available * (1 - CGFloat(frac))
    }
}

// Big chunky action button — START / RESET / RECORD.
struct BauhausButton: View {
    let title: String
    let color: Color
    var textColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(Theme.headline(28))
                .tracking(-1)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(color)
                .overlay(
                    Rectangle()
                        .stroke(Color.black, lineWidth: Theme.borderWidth)
                )
                .bauhausShadow()
        }
        .buttonStyle(.plain)
    }
}
