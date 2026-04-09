import SwiftUI

struct VisualizationView: View {
    @ObservedObject var audioEngine: VoiceChangerAudioEngine
    @ObservedObject var voiceProcessor: VoiceProcessor
    @State private var selectedTab = 0

    var body: some View {
        VStack {
            Picker("Visualization Mode", selection: $selectedTab) {
                Text("Waveform").tag(0)
                Text("Spectrum").tag(1)
                Text("Spectrogram").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            // Use conditional rendering instead of TabView to avoid pre-rendering all pages
            Group {
                switch selectedTab {
                case 0:
                    WaveformView(waveformData: audioEngine.waveformData)
                case 1:
                    SpectrumView(spectrumData: audioEngine.spectrumData)
                case 2:
                    SpectrogramView(spectrumData: audioEngine.spectrumData)
                default:
                    WaveformView(waveformData: audioEngine.waveformData)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
    }
}

struct WaveformView: View {
    let waveformData: [Float]

    var body: some View {
        Canvas { context, size in
            guard !waveformData.isEmpty else { return }

            let path = Path { path in
                let stepWidth = size.width / CGFloat(waveformData.count)
                let midY = size.height / 2

                for (index, sample) in waveformData.enumerated() {
                    let x = CGFloat(index) * stepWidth
                    let y = midY + CGFloat(sample) * midY * 0.8

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }

            // Draw background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.1))
            )

            // Draw center line
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                },
                with: .color(.gray.opacity(0.5)),
                lineWidth: 1
            )

            // Draw waveform
            context.stroke(
                path,
                with: .color(.blue),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SpectrumView: View {
    let spectrumData: [Float]

    var body: some View {
        Canvas { context, size in
            guard !spectrumData.isEmpty else { return }

            let barWidth = size.width / CGFloat(spectrumData.count)

            // Draw background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.1))
            )

            // Draw frequency bars
            for (index, magnitude) in spectrumData.enumerated() {
                let normalizedMagnitude = max(0, (magnitude + 100) / 100) // Convert from dB
                let barHeight = size.height * CGFloat(normalizedMagnitude)
                let x = CGFloat(index) * barWidth

                // Color based on frequency
                let hue = Double(index) / Double(spectrumData.count) * 240 / 360 // Blue to red
                let color = Color(hue: hue, saturation: 0.7, brightness: 0.8)

                let barRect = CGRect(
                    x: x,
                    y: size.height - barHeight,
                    width: barWidth,
                    height: barHeight
                )

                context.fill(Path(barRect), with: .color(color))
            }

            // Draw frequency labels
            let frequencies = [100, 500, 1000, 2000, 5000, 10000]
            let sampleRate: Float = 48000

            for freq in frequencies {
                if Float(freq) < sampleRate / 2 {
                    let x = CGFloat(freq) / CGFloat(sampleRate / 2) * size.width
                    let label = freq >= 1000 ? "\(freq/1000)k" : "\(freq)"

                    context.draw(
                        Text(label)
                            .font(.caption)
                            .foregroundColor(.secondary),
                        at: CGPoint(x: x, y: size.height - 5),
                        anchor: .bottom
                    )
                }
            }
        }
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SpectrogramView: View {
    let spectrumData: [Float]
    @State private var spectrogramHistory: [[Float]] = []
    private let maxFrames = 100

    var body: some View {
        Canvas { context, size in
            // Add current spectrum to history
            if !spectrumData.isEmpty {
                var newHistory = spectrogramHistory
                newHistory.append(spectrumData)

                if newHistory.count > maxFrames {
                    newHistory.removeFirst()
                }

                DispatchQueue.main.async {
                    spectrogramHistory = newHistory
                }
            }

            guard !spectrogramHistory.isEmpty else { return }

            // Draw background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.1))
            )

            let frameWidth = size.width / CGFloat(maxFrames)

            // Draw spectrogram
            for (frameIndex, frame) in spectrogramHistory.enumerated() {
                let x = CGFloat(frameIndex) * frameWidth

                for (freqBin, magnitude) in frame.enumerated() {
                    let normalizedMagnitude = max(0, (magnitude + 100) / 100)
                    let y = size.height - (CGFloat(freqBin) / CGFloat(frame.count)) * size.height

                    // Color based on magnitude
                    let intensity = normalizedMagnitude
                    let color = Color(
                        red: Double(intensity),
                        green: Double(intensity * 0.5),
                        blue: Double(intensity * 0.2)
                    )

                    let pixelRect = CGRect(
                        x: x,
                        y: y,
                        width: frameWidth,
                        height: size.height / CGFloat(frame.count)
                    )

                    context.fill(Path(pixelRect), with: .color(color))
                }
            }
        }
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            // Timer to trigger updates - data updates happen in the Canvas
        }
    }
}

#Preview {
    VisualizationView(
        audioEngine: VoiceChangerAudioEngine(),
        voiceProcessor: VoiceProcessor()
    )
}