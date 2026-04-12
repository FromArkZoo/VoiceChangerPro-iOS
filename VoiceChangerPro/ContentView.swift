import SwiftUI
import AVFoundation

// Top-level Bauhaus shell. Four tabs — CONTROL / EQ / MODULES / PRESETS —
// driven by a custom bottom nav that matches the mockup (no system TabView
// chrome because the mockup wants square corners, black borders, accent fills).
struct ContentView: View {
    @StateObject private var audioEngine = VoiceChangerAudioEngine()
    @StateObject private var voiceProcessor = VoiceProcessor()
    @StateObject private var presetManager = PresetManager()
    @StateObject private var recordingManager = RecordingManager()

    @State private var selectedTab: Tab = .control
    @State private var showingRecordings = false

    enum Tab: Int, CaseIterable {
        case control, equalizer, modules, presets

        var title: String {
            switch self {
            case .control: return "Control"
            case .equalizer: return "EQ"
            case .modules: return "Modules"
            case .presets: return "Presets"
            }
        }

        var symbol: String {
            switch self {
            case .control: return "slider.horizontal.3"
            case .equalizer: return "chart.bar.fill"
            case .modules: return "puzzlepiece.fill"
            case .presets: return "list.bullet.rectangle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .control:
                    ControlTabView(audioEngine: audioEngine, recordingManager: recordingManager)
                case .equalizer:
                    EqualizerView(audioEngine: audioEngine)
                case .modules:
                    ModulesView(audioEngine: audioEngine)
                case .presets:
                    PresetsView(audioEngine: audioEngine,
                                voiceProcessor: voiceProcessor,
                                presetManager: presetManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomNav
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(isPresented: $showingRecordings) {
            RecordingsListView(recordingManager: recordingManager, audioEngine: audioEngine)
        }
        .onAppear {
            audioEngine.onRecordingFinished = { url in
                recordingManager.addRecording(url: url)
            }
        }
    }

    private var bottomNav: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black).frame(height: Theme.borderWidth)

            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.rawValue) { tab in
                    tabButton(tab)
                    if tab != Tab.allCases.last {
                        Rectangle().fill(Color.black).frame(width: Theme.thinBorderWidth)
                    }
                }
            }
            .frame(height: 72)
            .background(Theme.background)
        }
    }

    private func tabButton(_ tab: Tab) -> some View {
        let active = tab == selectedTab
        return Button(action: { selectedTab = tab }) {
            VStack(spacing: 4) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 22, weight: .black))
                Text(tab.title.uppercased())
                    .font(Theme.label(10))
                    .tracking(2)
            }
            .foregroundColor(active ? .white : .black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(active ? Theme.primary : Theme.background)
        }
        .buttonStyle(.plain)
    }

    private func requestMicrophonePermission() {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                if !granted { NSLog("Microphone permission denied") }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if !granted { NSLog("Microphone permission denied") }
            }
        }
        #endif
    }
}

#Preview {
    ContentView()
}
