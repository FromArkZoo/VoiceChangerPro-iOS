import SwiftUI

struct RecordingsListView: View {
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var audioEngine: VoiceChangerAudioEngine
    @Environment(\.dismiss) private var dismiss

    @State private var showingShareSheet = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationView {
            Group {
                if recordingManager.recordings.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "mic.slash.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Recordings Yet")
                            .font(.title2)
                            .foregroundColor(.secondary)

                        Text("Start recording to see your recordings here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(recordingManager.recordings) { recording in
                            RecordingRow(
                                recording: recording,
                                isPlaying: audioEngine.isPlayingBack,
                                onPlay: {
                                    audioEngine.startPlayback(url: recording.url)
                                },
                                onStop: {
                                    audioEngine.stopPlayback()
                                },
                                onShare: {
                                    shareURL = recording.url
                                    showingShareSheet = true
                                }
                            )
                        }
                        .onDelete { indexSet in
                            recordingManager.deleteRecordings(at: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("Recordings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !recordingManager.recordings.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
}

struct RecordingRow: View {
    let recording: Recording
    let isPlaying: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Play/Stop button
            Button(action: {
                if isPlaying {
                    onStop()
                } else {
                    onPlay()
                }
            }) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isPlaying ? .red : .blue)
            }
            .buttonStyle(PlainButtonStyle())

            // Recording info
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.filename)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(recording.formattedDuration)
                            .font(.caption)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "doc")
                            .font(.caption2)
                        Text(recording.formattedFileSize)
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)

                Text(recording.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Share button
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

// Share sheet for iOS
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

#Preview {
    RecordingsListView(
        recordingManager: RecordingManager(),
        audioEngine: VoiceChangerAudioEngine()
    )
}
