import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioEngine = VoiceChangerAudioEngine()
    @StateObject private var voiceProcessor = VoiceProcessor()
    @StateObject private var presetManager = PresetManager()
    @StateObject private var recordingManager = RecordingManager()

    @State private var showingPresetSheet = false
    @State private var showingSavePresetAlert = false
    @State private var showingRecordingsSheet = false
    @State private var newPresetName = ""

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                if geometry.size.width > 800 {
                    // iPad/Large iPhone landscape layout
                    HStack(spacing: 0) {
                        // Left sidebar - Controls
                        ControlsView(audioEngine: audioEngine,
                                   voiceProcessor: voiceProcessor,
                                   presetManager: presetManager)
                            .frame(width: 320)
                            .background(Color(.systemGray6))

                        // Center - Visualization and Main Controls
                        VStack {
                            MainControlsView(audioEngine: audioEngine,
                                           recordingManager: recordingManager)
                                .padding()

                            VisualizationView(audioEngine: audioEngine,
                                            voiceProcessor: voiceProcessor)
                                .frame(maxHeight: 300)

                            LevelMetersView(audioEngine: audioEngine)
                                .padding()

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)

                        // Right sidebar - Visualization modes
                        VStack {
                            Text("Analysis")
                                .font(.headline)
                                .padding()

                            VoiceAnalysisView(voiceProcessor: voiceProcessor)
                                .padding()

                            Spacer()
                        }
                        .frame(width: 280)
                        .background(Color(.systemGray6))
                    }
                } else {
                    // iPhone portrait layout
                    VStack {
                        MainControlsView(audioEngine: audioEngine,
                                       recordingManager: recordingManager)
                            .padding()

                        TabView {
                            ControlsView(audioEngine: audioEngine,
                                       voiceProcessor: voiceProcessor,
                                       presetManager: presetManager)
                                .tabItem {
                                    Image(systemName: "slider.horizontal.3")
                                    Text("Controls")
                                }

                            VisualizationView(audioEngine: audioEngine,
                                            voiceProcessor: voiceProcessor)
                                .tabItem {
                                    Image(systemName: "waveform")
                                    Text("Visualization")
                                }

                            VoiceAnalysisView(voiceProcessor: voiceProcessor)
                                .tabItem {
                                    Image(systemName: "chart.bar.fill")
                                    Text("Analysis")
                                }
                        }
                    }
                }
            }
            .navigationTitle("🎤 Voice Changer Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingRecordingsSheet = true
                    }) {
                        Label("Recordings", systemImage: "folder")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Presets") {
                        showingPresetSheet = true
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingPresetSheet) {
            PresetSelectionView(presetManager: presetManager,
                              audioEngine: audioEngine,
                              voiceProcessor: voiceProcessor)
        }
        .sheet(isPresented: $showingRecordingsSheet) {
            RecordingsListView(recordingManager: recordingManager,
                             audioEngine: audioEngine)
        }
        .onAppear {
            requestMicrophonePermission()
            audioEngine.onRecordingFinished = { url in
                recordingManager.addRecording(url: url)
            }
        }
    }

    private func requestMicrophonePermission() {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                if !granted {
                    // Handle permission denied
                    print("Microphone permission denied")
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if !granted {
                    // Handle permission denied
                    print("Microphone permission denied")
                }
            }
        }
        #endif
    }
}

struct MainControlsView: View {
    @ObservedObject var audioEngine: VoiceChangerAudioEngine
    @ObservedObject var recordingManager: RecordingManager

    var body: some View {
        VStack(spacing: 16) {
            // Main control buttons
            HStack(spacing: 20) {
                Button(action: {
                    if audioEngine.isProcessing {
                        audioEngine.stopProcessing()
                    } else {
                        #if os(iOS)
                        if #available(iOS 17.0, *) {
                            AVAudioApplication.requestRecordPermission { granted in
                                if granted {
                                    DispatchQueue.main.async {
                                        do {
                                            try audioEngine.startProcessing()
                                        } catch {
                                            print("Failed to start audio processing: \(error.localizedDescription)")
                                        }
                                    }
                                } else {
                                    print("Microphone permission denied")
                                }
                            }
                        } else {
                            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                                if granted {
                                    DispatchQueue.main.async {
                                        do {
                                            try audioEngine.startProcessing()
                                        } catch {
                                            print("Failed to start audio processing: \(error.localizedDescription)")
                                        }
                                    }
                                } else {
                                    print("Microphone permission denied")
                                }
                            }
                        }
                        #else
                        do {
                            try audioEngine.startProcessing()
                        } catch {
                            print("Failed to start audio processing: \(error.localizedDescription)")
                        }
                        #endif
                    }
                }) {
                    HStack {
                        Image(systemName: audioEngine.isProcessing ? "stop.fill" : "play.fill")
                        Text(audioEngine.isProcessing ? "Stop" : "Start")
                    }
                    .padding()
                    .frame(minWidth: 120)
                    .background(audioEngine.isProcessing ?
                               Color.red.gradient : Color.blue.gradient)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Reset") {
                    audioEngine.resetToFactory()
                }
                .padding()
                .background(Color.gray.gradient)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Recording controls
            if audioEngine.isProcessing {
                HStack(spacing: 16) {
                    Button(action: {
                        if audioEngine.isRecording {
                            if let url = audioEngine.stopRecording() {
                                recordingManager.addRecording(url: url)
                            }
                        } else {
                            audioEngine.startRecording()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: audioEngine.isRecording ? "stop.circle.fill" : "circle.fill")
                            Text(audioEngine.isRecording ? "Stop Recording" : "Record")

                            if audioEngine.isRecording {
                                Text(formatDuration(audioEngine.getRecordingDuration()))
                                    .monospacedDigit()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(audioEngine.isRecording ?
                                   Color.red.gradient : Color.green.gradient)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            // Status indicators
            HStack(spacing: 20) {
                HStack {
                    Circle()
                        .fill(audioEngine.isProcessing ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                    Text("Status")
                        .font(.caption)
                }

                Text("Latency: \(String(format: "%.1f", audioEngine.getLatency() * 1000))ms")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Headphone status indicator
                HStack(spacing: 4) {
                    Image(systemName: audioEngine.isHeadphonesConnected ? "headphones" : "speaker.wave.2")
                        .foregroundColor(audioEngine.isHeadphonesConnected ? .green : .orange)
                    Text(audioEngine.isHeadphonesConnected ? "Safe" : "Feedback Risk")
                        .font(.caption)
                        .foregroundColor(audioEngine.isHeadphonesConnected ? .green : .orange)
                }
            }

            // Feedback warning banner
            if audioEngine.isProcessing && !audioEngine.isHeadphonesConnected {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Connect headphones to prevent feedback and unlock full volume")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct LevelMetersView: View {
    @ObservedObject var audioEngine: VoiceChangerAudioEngine

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Input")
                    .frame(width: 60, alignment: .leading)

                LevelMeterBar(level: audioEngine.inputLevel)

                Circle()
                    .fill(audioEngine.inputLevel > 0.95 ? Color.red : Color.gray)
                    .frame(width: 8, height: 8)
            }

            HStack {
                Text("Output")
                    .frame(width: 60, alignment: .leading)

                LevelMeterBar(level: audioEngine.outputLevel)

                Circle()
                    .fill(audioEngine.outputLevel > 0.95 ? Color.red : Color.gray)
                    .frame(width: 8, height: 8)
            }
        }
        .font(.caption)
    }
}

struct LevelMeterBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.3))

                Rectangle()
                    .fill(LinearGradient(
                        colors: [.green, .yellow, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geometry.size.width * CGFloat(min(level, 1.0)))
            }
        }
        .frame(height: 8)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct VoiceAnalysisView: View {
    @ObservedObject var voiceProcessor: VoiceProcessor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                HStack {
                    Text("Fundamental Frequency:")
                    Spacer()
                    Text("\(String(format: "%.1f", voiceProcessor.fundamentalFrequency)) Hz")
                        .foregroundColor(.blue)
                }

                HStack {
                    Text("Voice Activity:")
                    Spacer()
                    Text("\(String(format: "%.0f", voiceProcessor.voiceActivity * 100))%")
                        .foregroundColor(.green)
                }

                HStack {
                    Text("Spectral Centroid:")
                    Spacer()
                    Text("\(String(format: "%.0f", voiceProcessor.spectralCentroid)) Hz")
                        .foregroundColor(.orange)
                }
            }
            .font(.caption)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}