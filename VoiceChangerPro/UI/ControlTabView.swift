import SwiftUI
import AVFoundation

// CONTROL tab — the "hero" screen in the Bauhaus mockup.
// Composes: brand header, signal monitor, morphing XY pad, START/RESET,
// record row, a small decorative status strip. Only the primitives defined
// in Theme / BauhausControls / MorphingPadView / SignalMonitorView are used.
struct ControlTabView: View {
    @ObservedObject var audioEngine: VoiceChangerAudioEngine
    @ObservedObject var recordingManager: RecordingManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                signalStrip

                PageHeader(kicker: "Live Control", title: "MORPH\nTHE PAD")

                MorphingPadView(audioEngine: audioEngine)
                    .padding(.vertical, 4)

                HStack(spacing: 16) {
                    BauhausButton(title: audioEngine.isProcessing ? "STOP" : "START",
                                  color: audioEngine.isProcessing ? Theme.primary : Theme.secondary) {
                        toggleProcessing()
                    }
                    BauhausButton(title: "RESET",
                                  color: Theme.tertiary,
                                  textColor: .black) {
                        audioEngine.resetToFactory()
                    }
                }

                recordRow

                decorativeStrip
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                TagLabel(text: "JB", filled: .black)
                Text("VOICECHANGER")
                    .font(Theme.headline(28))
                    .tracking(-1)
                    .foregroundColor(.black)
            }
            Spacer()
            statusBadge
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(audioEngine.isProcessing ? Theme.secondary : Color.black.opacity(0.35))
                .frame(width: 10, height: 10)
            Text(audioEngine.isProcessing ? "LIVE" : "IDLE")
                .font(Theme.label(10))
                .tracking(2)
                .foregroundColor(.black)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
    }

    private var signalStrip: some View {
        HStack(alignment: .top, spacing: 12) {
            SignalMonitorView(audioEngine: audioEngine)
                .padding(12)
                .background(Theme.surfaceContainer)
                .bauhausBorder()

            VStack(alignment: .leading, spacing: 4) {
                TagLabel(text: "MOD-01", filled: .black)
                Text(String(format: "%.1fms", audioEngine.getLatency() * 1000))
                    .font(Theme.label(12))
                    .foregroundColor(.black)
            }
            .padding(12)
            .frame(width: 110, height: 120)
            .background(Theme.tertiary)
            .bauhausBorder()
        }
    }

    private var recordRow: some View {
        HStack(spacing: 12) {
            Button(action: toggleRecording) {
                HStack(spacing: 8) {
                    Image(systemName: audioEngine.isRecording ? "stop.fill" : "record.circle")
                        .font(.system(size: 18, weight: .bold))
                    Text(audioEngine.isRecording ? "STOP REC" : "RECORD")
                        .font(Theme.label(14))
                        .tracking(2)
                    if audioEngine.isRecording {
                        Text(formatDuration(audioEngine.getRecordingDuration()))
                            .font(Theme.label(14))
                            .monospacedDigit()
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(audioEngine.isRecording ? Color.black : Theme.primary)
                .overlay(Rectangle().stroke(Color.black, lineWidth: Theme.borderWidth))
                .bauhausShadow()
            }
            .buttonStyle(.plain)
            .disabled(!audioEngine.isProcessing)
            .opacity(audioEngine.isProcessing ? 1.0 : 0.5)
        }
    }

    private var decorativeStrip: some View {
        HStack(spacing: 12) {
            decoTile(content: AnyView(
                Text("44.1\nKHZ")
                    .font(Theme.headline(18))
                    .tracking(-1)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
            ), background: Theme.tertiary)

            decoTile(content: AnyView(
                Image(systemName: audioEngine.isHeadphonesConnected ? "headphones" : "speaker.wave.2.fill")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
            ), background: .black)

            decoTile(content: AnyView(
                Image(systemName: "mic.fill")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
            ), background: Theme.primary)

            decoTile(content: AnyView(
                Image(systemName: "waveform")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
            ), background: Theme.secondary)
        }
        .frame(height: 88)
    }

    private func decoTile(content: AnyView, background: Color) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
            .bauhausBorder()
    }

    private func toggleProcessing() {
        if audioEngine.isProcessing {
            audioEngine.stopProcessing()
            return
        }
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else { return }
                DispatchQueue.main.async { tryStart() }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                guard granted else { return }
                DispatchQueue.main.async { tryStart() }
            }
        }
        #else
        tryStart()
        #endif

        func tryStart() {
            do { try audioEngine.startProcessing() }
            catch { NSLog("VCP-UI startProcessing failed: \(error.localizedDescription)") }
        }
    }

    private func toggleRecording() {
        if audioEngine.isRecording {
            if let url = audioEngine.stopRecording() {
                recordingManager.addRecording(url: url)
            }
        } else {
            audioEngine.startRecording()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
