import AVFoundation
import Foundation

class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    private var audioFile: AVAudioFile?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    var currentRecordingURL: URL?

    func startRecording(format: AVAudioFormat) throws -> AVAudioFile {
        print("🎙️ AudioRecorder: Starting recording...")
        print("   Input format: \(format)")
        print("   Sample rate: \(format.sampleRate), Channels: \(format.channelCount)")
        
        // Create a unique filename with timestamp
        let timestamp = Date().timeIntervalSince1970
        let filename = "VoiceChanger_\(Int(timestamp)).caf"  // Use CAF for better compatibility

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(filename)

        currentRecordingURL = audioURL
        
        print("   Recording to: \(audioURL.lastPathComponent)")

        // CRITICAL FIX: Use the format directly instead of settings dictionary
        // This ensures format compatibility with the audio engine
        do {
            // Create the audio file using the exact format from the engine
            audioFile = try AVAudioFile(forWriting: audioURL, settings: format.settings)
            
            print("   ✅ Audio file created successfully")
        } catch {
            print("   ❌ Failed to create audio file: \(error)")
            throw error
        }

        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0

        // Start timer for duration updates
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.recordingDuration = Date().timeIntervalSince(startTime)
        }

        return audioFile!
    }

    func writeBuffer(_ buffer: AVAudioPCMBuffer) throws {
        guard let audioFile = audioFile, isRecording else { return }
        try audioFile.write(from: buffer)
    }

    func stopRecording() -> URL? {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        audioFile = nil

        let url = currentRecordingURL
        currentRecordingURL = nil
        recordingStartTime = nil

        return url
    }

    func cancelRecording() {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Delete the file if it exists
        if let url = currentRecordingURL {
            do {
                try FileManager.default.removeItem(at: url)
                print("Cancelled recording file deleted: \(url.lastPathComponent)")
            } catch {
                print("Warning: Failed to delete cancelled recording: \(error.localizedDescription)")
            }
        }

        audioFile = nil
        currentRecordingURL = nil
        recordingStartTime = nil
    }
}
