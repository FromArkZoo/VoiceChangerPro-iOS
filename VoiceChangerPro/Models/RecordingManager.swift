import Foundation
import AVFoundation

struct Recording: Identifiable, Codable {
    let id: UUID
    let filename: String
    let date: Date
    let duration: TimeInterval
    let fileSize: Int64

    var url: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(filename)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

class RecordingManager: ObservableObject {
    @Published var recordings: [Recording] = []

    init() {
        loadRecordings()
    }

    func loadRecordings() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )

            // Filter for audio files (including CAF format)
            let audioFiles = fileURLs.filter { url in
                let ext = url.pathExtension.lowercased()
                return ext == "m4a" || ext == "wav" || ext == "mp3" || ext == "aac" || ext == "caf"
            }

            // Create Recording objects
            recordings = audioFiles.compactMap { url in
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let fileSize = attributes[.size] as? Int64,
                      let creationDate = attributes[.creationDate] as? Date else {
                    return nil
                }

                // Get duration from audio file
                let duration = getAudioDuration(url: url)

                return Recording(
                    id: UUID(),
                    filename: url.lastPathComponent,
                    date: creationDate,
                    duration: duration,
                    fileSize: fileSize
                )
            }

            // Sort by date, newest first
            recordings.sort { $0.date > $1.date }
        } catch {
            print("Error loading recordings: \(error)")
        }
    }

    func addRecording(url: URL) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64,
              let creationDate = attributes[.creationDate] as? Date else {
            return
        }

        let duration = getAudioDuration(url: url)

        let recording = Recording(
            id: UUID(),
            filename: url.lastPathComponent,
            date: creationDate,
            duration: duration,
            fileSize: fileSize
        )

        recordings.insert(recording, at: 0)
    }

    func deleteRecording(_ recording: Recording) {
        do {
            try FileManager.default.removeItem(at: recording.url)
            recordings.removeAll { $0.id == recording.id }
        } catch {
            print("Error deleting recording: \(error)")
        }
    }

    func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = recordings[index]
            try? FileManager.default.removeItem(at: recording.url)
        }
        recordings.remove(atOffsets: offsets)
    }

    func shareRecording(_ recording: Recording) -> URL {
        return recording.url
    }

    private func getAudioDuration(url: URL) -> TimeInterval {
        do {
            // Check if file exists first
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("⚠️ Audio file does not exist: \(url.lastPathComponent)")
                return 0
            }
            
            // Check file size
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if fileSize == 0 {
                print("⚠️ Audio file is empty: \(url.lastPathComponent)")
                return 0
            }
            
            print("📂 Reading audio file: \(url.lastPathComponent) (\(fileSize) bytes)")
            
            let audioFile = try AVAudioFile(forReading: url)
            let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
            
            print("   ✅ Duration: \(String(format: "%.2f", duration))s")
            
            return duration
        } catch let error as NSError {
            print("❌ Error getting audio duration for \(url.lastPathComponent)")
            print("   Error: \(error.localizedDescription)")
            print("   Domain: \(error.domain)")
            print("   Code: \(error.code)")
            
            // Try to provide helpful error messages
            if error.code == 1685348671 {
                print("   ⚠️ File format issue - file may be corrupted or incomplete")
            }
            
            return 0
        }
    }
}
