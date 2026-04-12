import SwiftUI

// XY morphing pad — X axis → pitchShift (-12..+12 semitones),
// Y axis → reverbAmount (0..1, inverted so "up" = more reverb).
// Styled to the Bauhaus mockup: 4px black border, grid background, red puck.
struct MorphingPadView: View {
    @ObservedObject var audioEngine: VoiceChangerAudioEngine

    var body: some View {
        GeometryReader { geo in
            ZStack {
                gridBackground(size: geo.size)

                // Corner labels
                labels

                // Draggable puck
                let puckPos = currentPuckPosition(in: geo.size)
                Rectangle()
                    .fill(Theme.primary)
                    .frame(width: 32, height: 32)
                    .bauhausBorder()
                    .position(x: puckPos.x, y: puckPos.y)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedX = max(0, min(geo.size.width, value.location.x))
                        let clampedY = max(0, min(geo.size.height, value.location.y))
                        let xFrac = Float(clampedX / geo.size.width)
                        let yFrac = Float(clampedY / geo.size.height)
                        audioEngine.pitchShift = (xFrac * 2 - 1) * 12
                        audioEngine.reverbAmount = 1 - yFrac
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .bauhausBorder()
    }

    private func currentPuckPosition(in size: CGSize) -> CGPoint {
        let xFrac = CGFloat((audioEngine.pitchShift + 12) / 24)
        let yFrac = CGFloat(1 - audioEngine.reverbAmount)
        return CGPoint(x: xFrac * size.width, y: yFrac * size.height)
    }

    private func gridBackground(size: CGSize) -> some View {
        Canvas { context, _ in
            let step = size.width / 8
            var cols = stride(from: 0.0, through: size.width, by: step).makeIterator()
            while let x = cols.next() {
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }, with: .color(.black.opacity(0.12)), lineWidth: 1)
            }
            var rows = stride(from: 0.0, through: size.height, by: step).makeIterator()
            while let y = rows.next() {
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }, with: .color(.black.opacity(0.12)), lineWidth: 1)
            }
        }
    }

    private var labels: some View {
        VStack {
            HStack {
                Spacer()
                TagLabel(text: "Sharp", filled: .black)
                    .padding(8)
            }
            Spacer()
            HStack {
                TagLabel(text: "Deep", filled: .black)
                    .padding(8)
                Spacer()
            }
        }
    }
}
