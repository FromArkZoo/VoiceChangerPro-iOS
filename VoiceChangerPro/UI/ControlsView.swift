import SwiftUI

struct ControlsView: View {
    @ObservedObject var audioEngine: VoiceChangerAudioEngine
    @ObservedObject var voiceProcessor: VoiceProcessor
    @ObservedObject var presetManager: PresetManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Voice Transformation Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "🎭 Voice Transformation")

                    VoiceParameterSlider(
                        title: "Pitch Shift",
                        value: $audioEngine.pitchShift,
                        range: -12...12,
                        unit: "st",
                        format: "%.1f"
                    )

                    VoiceParameterSlider(
                        title: "Formant Shift",
                        value: $audioEngine.formantShift,
                        range: 0.5...2.0,
                        unit: "x",
                        format: "%.2f"
                    )

                    VoiceParameterSlider(
                        title: "Time Stretch",
                        value: $audioEngine.timeStretch,
                        range: 0.5...2.0,
                        unit: "x",
                        format: "%.2f"
                    )

                    VoiceParameterSlider(
                        title: "Vocal Tract Length",
                        value: $audioEngine.vocalTractLength,
                        range: 0.5...2.0,
                        unit: "x",
                        format: "%.2f"
                    )
                }

                Divider()

                // EQ Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "🎚️ Equalizer")

                    VoiceParameterSlider(
                        title: "Bass",
                        value: $audioEngine.bassGain,
                        range: -12...12,
                        unit: "dB",
                        format: "%.1f"
                    )

                    VoiceParameterSlider(
                        title: "Mid",
                        value: $audioEngine.midGain,
                        range: -12...12,
                        unit: "dB",
                        format: "%.1f"
                    )

                    VoiceParameterSlider(
                        title: "Treble",
                        value: $audioEngine.trebleGain,
                        range: -12...12,
                        unit: "dB",
                        format: "%.1f"
                    )
                }

                Divider()

                // Effects Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "✨ Effects")

                    VoiceParameterSlider(
                        title: "Reverb",
                        value: $audioEngine.reverbAmount,
                        range: 0...1,
                        unit: "%",
                        format: "%.0f",
                        multiplier: 100
                    )

                    VoiceParameterSlider(
                        title: "Bit Depth",
                        value: $audioEngine.bitDepth,
                        range: 2...16,
                        unit: "bit",
                        format: "%.0f"
                    )

                    VoiceParameterSlider(
                        title: "Noise Reduction",
                        value: $audioEngine.noiseReduction,
                        range: 0...1,
                        unit: "%",
                        format: "%.0f",
                        multiplier: 100
                    )
                }

                Divider()

                // Master Controls
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "🔧 Master")

                    VoiceParameterSlider(
                        title: "Master Volume",
                        value: $audioEngine.masterVolume,
                        range: 0...5,  // Allow up to 5x amplification
                        unit: "%",
                        format: "%.0f",
                        multiplier: 100
                    )
                }

                Divider()

                // XY Morphing Pad
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "🎛️ Voice Morphing Pad")

                    VoiceMorphingPad(audioEngine: audioEngine)
                        .frame(height: 200)
                        .background(Color.black.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.bottom, 4)
    }
}

struct VoiceParameterSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let unit: String
    let format: String
    let multiplier: Float

    init(title: String,
         value: Binding<Float>,
         range: ClosedRange<Float>,
         unit: String,
         format: String,
         multiplier: Float = 1.0) {
        self.title = title
        self._value = value
        self.range = range
        self.unit = unit
        self.format = format
        self.multiplier = multiplier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: format, value * multiplier)) \(unit)")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .monospaced()
            }

            Slider(value: $value, in: range) {
                Text(title)
            }
            .accentColor(.blue)
        }
    }
}

struct VoiceMorphingPad: View {
    @ObservedObject var audioEngine: VoiceChangerAudioEngine
    @State private var dragPosition = CGPoint(x: 0.5, y: 0.5)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height

                    // Vertical lines
                    for i in 0...4 {
                        let x = width * CGFloat(i) / 4
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }

                    // Horizontal lines
                    for i in 0...4 {
                        let y = height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                // Center lines
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height

                    // Center vertical
                    path.move(to: CGPoint(x: width / 2, y: 0))
                    path.addLine(to: CGPoint(x: width / 2, y: height))

                    // Center horizontal
                    path.move(to: CGPoint(x: 0, y: height / 2))
                    path.addLine(to: CGPoint(x: width, y: height / 2))
                }
                .stroke(Color.gray.opacity(0.6), lineWidth: 2)

                // Control point
                Circle()
                    .fill(Color.red)
                    .frame(width: 16, height: 16)
                    .position(
                        x: dragPosition.x * geometry.size.width,
                        y: dragPosition.y * geometry.size.height
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 16, height: 16)
                            .position(
                                x: dragPosition.x * geometry.size.width,
                                y: dragPosition.y * geometry.size.height
                            )
                    )

                // Labels
                VStack {
                    Spacer()
                    HStack {
                        Text("Lower")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Pitch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Higher")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }

                HStack {
                    VStack {
                        Text("High")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(-90))
                        Spacer()
                        Text("Formant")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(-90))
                        Spacer()
                        Text("Low")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(-90))
                    }
                    .padding(.leading, 4)
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = max(0, min(1, value.location.x / geometry.size.width))
                        let y = max(0, min(1, value.location.y / geometry.size.height))
                        dragPosition = CGPoint(x: x, y: y)

                        // Map to audio parameters
                        let pitchShift = (x - 0.5) * 24 // ±12 semitones
                        let formantShift = 0.5 + y // 0.5 to 1.5

                        audioEngine.pitchShift = Float(pitchShift)
                        audioEngine.formantShift = Float(formantShift)
                    }
            )
        }
    }
}

struct PresetSelectionView: View {
    @ObservedObject var presetManager: PresetManager
    @ObservedObject var audioEngine: VoiceChangerAudioEngine
    @ObservedObject var voiceProcessor: VoiceProcessor

    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveAlert = false
    @State private var newPresetName = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(presetManager.presets.indices, id: \.self) { index in
                    PresetRow(
                        preset: presetManager.presets[index],
                        isSelected: presetManager.selectedPresetIndex == index,
                        isBuiltIn: index < VoicePreset.presets.count
                    ) {
                        applyPreset(at: index)
                        dismiss()
                    } onDelete: {
                        presetManager.deletePreset(at: index)
                    }
                }
            }
            .navigationTitle("Voice Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save Current") {
                        showingSaveAlert = true
                    }
                }
            }
            .alert("Save Preset", isPresented: $showingSaveAlert) {
                TextField("Preset Name", text: $newPresetName)
                Button("Save") {
                    saveCurrentPreset()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter a name for your custom preset")
            }
        }
    }

    private func applyPreset(at index: Int) {
        let preset = presetManager.presets[index]
        voiceProcessor.applyPreset(preset, to: audioEngine)
        presetManager.selectPreset(at: index)
    }

    private func saveCurrentPreset() {
        guard !newPresetName.isEmpty else { return }

        let preset = voiceProcessor.createCustomPreset(from: audioEngine, name: newPresetName)
        presetManager.saveCustomPreset(preset)
        newPresetName = ""
    }
}

struct PresetRow: View {
    let preset: VoicePreset
    let isSelected: Bool
    let isBuiltIn: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(preset.name)
                    .font(.headline)
                    .foregroundColor(isSelected ? .blue : .primary)

                Text("Pitch: \(String(format: "%.1f", preset.pitch))st, Formant: \(String(format: "%.2f", preset.formant))x")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }

            if !isBuiltIn {
                Button("Delete") {
                    onDelete()
                }
                .foregroundColor(.red)
                .font(.caption)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    ControlsView(
        audioEngine: VoiceChangerAudioEngine(),
        voiceProcessor: VoiceProcessor(),
        presetManager: PresetManager()
    )
}