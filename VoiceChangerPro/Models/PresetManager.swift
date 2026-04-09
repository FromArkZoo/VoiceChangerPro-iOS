import Foundation
import SwiftUI

class PresetManager: ObservableObject {
    @Published var presets: [VoicePreset] = []
    @Published var selectedPresetIndex: Int? = nil

    private let userDefaultsKey = "VoiceChangerPresets"

    init() {
        loadPresets()
    }

    private func loadPresets() {
        // Start with built-in presets
        presets = VoicePreset.presets

        // Load custom presets from UserDefaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let customPresets = try JSONDecoder().decode([VoicePreset].self, from: data)
                presets.append(contentsOf: customPresets)
                print("Loaded \(customPresets.count) custom presets")
            } catch {
                print("Warning: Failed to decode custom presets: \(error.localizedDescription)")
                // Continue with just built-in presets
            }
        }
    }

    func saveCustomPreset(_ preset: VoicePreset) {
        // Add to current presets
        presets.append(preset)

        // Save only custom presets (after built-in ones)
        let customPresets = Array(presets.dropFirst(VoicePreset.presets.count))

        do {
            let data = try JSONEncoder().encode(customPresets)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("Saved custom preset: \(preset.name)")
        } catch {
            print("Warning: Failed to save custom preset: \(error.localizedDescription)")
        }
    }

    func deletePreset(at index: Int) {
        // Don't allow deletion of built-in presets
        guard index >= VoicePreset.presets.count else { return }

        presets.remove(at: index)

        // Update selected index if necessary
        if selectedPresetIndex == index {
            selectedPresetIndex = nil
        } else if let selectedIndex = selectedPresetIndex, selectedIndex > index {
            selectedPresetIndex = selectedIndex - 1
        }

        // Save updated custom presets
        let customPresets = Array(presets.dropFirst(VoicePreset.presets.count))
        do {
            let data = try JSONEncoder().encode(customPresets)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Warning: Failed to save presets after deletion: \(error.localizedDescription)")
        }
    }

    func selectPreset(at index: Int) {
        selectedPresetIndex = index
    }

    func getSelectedPreset() -> VoicePreset? {
        guard let index = selectedPresetIndex,
              index < presets.count else { return nil }
        return presets[index]
    }

    func clearSelection() {
        selectedPresetIndex = nil
    }
}