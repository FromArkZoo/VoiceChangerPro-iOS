# VoiceChangerPro - Step-by-Step Implementation Plan

## Current State Analysis

### Existing Components
- ✅ Basic audio engine with AVAudioEngine
- ✅ Pitch shifting via AVAudioUnitTimePitch
- ✅ EQ (user controls + formant processing)
- ✅ Reverb and distortion effects
- ✅ Recording functionality via AudioRecorder
- ✅ Basic FFT visualization
- ✅ Voice processor with analysis
- ✅ Preset management
- ✅ UI with controls and visualization

### Current Issues Identified
1. **FFT Memory Management**: Current implementation recreates FFTSetup on every call (performance issue)
2. **No Error Handling**: Missing error recovery system
3. **Basic Formant Shifting**: Using simple EQ adjustments instead of PSOLA
4. **No Buffer Pooling**: Allocating buffers repeatedly
5. **Limited Architecture**: Logic mixed in views, needs MVVM
6. **No Comprehensive Testing**: Missing test suite

---

## Implementation Roadmap

### 📋 PHASE 1: CRITICAL FIXES (Week 1) - Priority: URGENT

**Goal**: Fix memory leaks and crashes, implement proper error handling

#### Task 1.1: Replace FFT Implementation (Day 1-2)
**Files to create/modify:**
- Create: `VoiceChangerPro/Audio/Processing/OptimizedFFTProcessor.swift`
- Modify: `VoiceChangerPro/Audio/AudioEngine.swift` (lines 309-336)
- Modify: `VoiceChangerPro/Audio/VoiceProcessor.swift` (lines 40-121)

**Steps:**
1. Copy `OptimizedFFTProcessor.swift` from improvement files to `Audio/Processing/`
2. Update `AudioEngine.swift`:
   - Remove inline FFT code (lines 309-336)
   - Add property: `private var fftProcessor: OptimizedFFTProcessor!`
   - Initialize in init(): `fftProcessor = OptimizedFFTProcessor(fftLength: 1024)`
   - Replace `performFFT()` calls with `fftProcessor.processSpectrumWithBins()`
3. Update `VoiceProcessor.swift`:
   - Replace FFT setup/teardown (lines 40-54) with OptimizedFFTProcessor
   - Update `performFFT()` method to use new processor
4. Test thoroughly for memory leaks

**Expected Outcome**: No more FFT-related crashes, better performance

#### Task 1.2: Implement Error Handling System (Day 2-3)
**Files to create:**
- Create: `VoiceChangerPro/Core/Errors/AudioEngineError.swift`

**Steps:**
1. Copy error types from `ImprovedVoiceAudioEngine.swift` (lines 7-54)
2. Create new file with error definitions
3. Update `AudioEngine.swift` to throw/handle errors:
   - Wrap `startProcessing()` in do-catch with specific errors
   - Add recovery methods for each error type
   - Update UI to display errors to user
4. Add error state to UI (show alerts/banners)

**Expected Outcome**: Graceful error handling, no silent failures

#### Task 1.3: Add Buffer Pooling (Day 3-4)
**Files to create/modify:**
- Create: `VoiceChangerPro/Audio/Processing/AudioBufferPool.swift`
- Modify: `VoiceChangerPro/Audio/AudioEngine.swift`

**Steps:**
1. Copy `AudioBufferPool` class from `ImprovedVoiceAudioEngine.swift` (lines 503-539)
2. Create new file for buffer pool
3. Add to `AudioEngine.swift`:
   - Add property: `private var bufferPool: AudioBufferPool!`
   - Initialize in `setupIfNeeded()`
   - Use borrowed buffers in tap callbacks
4. Monitor memory usage improvement

**Expected Outcome**: Reduced memory allocations, smoother performance

---

### 📋 PHASE 2: ARCHITECTURE REFACTORING (Week 2) - Priority: HIGH

**Goal**: Clean up code organization, implement MVVM

#### Task 2.1: Reorganize File Structure (Day 1)
**Folder structure to create:**
```
VoiceChangerPro/
├── App/
│   └── VoiceChangerProApp.swift (existing)
├── Core/
│   ├── Audio/
│   │   ├── Engine/
│   │   │   └── VoiceAudioEngine.swift (move from Audio/)
│   │   ├── Processing/
│   │   │   ├── OptimizedFFTProcessor.swift (from Phase 1)
│   │   │   ├── AudioBufferPool.swift (from Phase 1)
│   │   │   └── VoiceProcessor.swift (move from Audio/)
│   │   └── Effects/
│   │       └── (future: custom effects)
│   ├── Recording/
│   │   ├── AudioRecorder.swift (existing)
│   │   └── RecordingManager.swift (existing)
│   ├── Presets/
│   │   └── PresetManager.swift (existing)
│   └── Errors/
│       └── AudioEngineError.swift (from Phase 1)
├── UI/
│   ├── Views/
│   │   ├── ContentView.swift (existing)
│   │   ├── ControlsView.swift (existing)
│   │   ├── VisualizationView.swift (existing)
│   │   └── RecordingsListView.swift (existing)
│   └── ViewModels/
│       └── AudioEngineViewModel.swift (to create)
└── Models/
    └── VoicePreset.swift (extract from VoiceProcessor.swift)
```

**Steps:**
1. Create new folder structure in Xcode
2. Move files to new locations (drag in Xcode, update groups)
3. Fix all import statements
4. Update Xcode project file references
5. Build and verify no errors

**Expected Outcome**: Clean, organized project structure

#### Task 2.2: Implement MVVM Pattern (Day 2-4)
**Files to create:**
- Create: `VoiceChangerPro/UI/ViewModels/AudioEngineViewModel.swift`

**Steps:**
1. Create ViewModel with @MainActor annotation
2. Move all Published properties from AudioEngine to ViewModel
3. Inject AudioEngine, PresetManager, RecordingManager as dependencies
4. Update ContentView to use ViewModel instead of direct engine access
5. Move business logic from views to ViewModel
6. Ensure proper state management

**Code template:**
```swift
@MainActor
class AudioEngineViewModel: ObservableObject {
    private let audioEngine: VoiceChangerAudioEngine
    private let presetManager: PresetManager
    private let recordingManager: RecordingManager

    @Published var isProcessing: Bool = false
    @Published var currentError: AudioEngineError?
    // ... other published properties

    init(
        audioEngine: VoiceChangerAudioEngine = VoiceChangerAudioEngine(),
        presetManager: PresetManager = PresetManager(),
        recordingManager: RecordingManager = RecordingManager()
    ) {
        self.audioEngine = audioEngine
        self.presetManager = presetManager
        self.recordingManager = recordingManager
    }

    func startProcessing() async {
        // Handle async operations
    }
}
```

**Expected Outcome**: Cleaner separation of concerns, testable code

---

### 📋 PHASE 3: ADVANCED FORMANT PROCESSING (Week 3) - Priority: HIGH

**Goal**: Implement professional-grade formant shifting with PSOLA

#### Task 3.1: Integrate FormantShifter (Day 1-3)
**Files to create:**
- Create: `VoiceChangerPro/Core/Audio/Processing/FormantShifter.swift`

**Steps:**
1. Copy `FormantShifter.swift` from improvement files
2. Add to project in Processing folder
3. Update `AudioEngine.swift`:
   - Add property: `private var formantShifter: FormantShifter!`
   - Initialize with sample rate
   - Replace simple EQ-based formant shifting (lines 547-552)
4. Integrate into audio processing chain:
   - Process buffers through FormantShifter in tap callback
   - Handle real-time performance requirements
5. Test with various formant shift values

**Expected Outcome**: High-quality formant shifting without pitch changes

#### Task 3.2: Add Vocal Tract Length Processing (Day 3-4)
**Steps:**
1. Use `VocalTractLengthModifier` from FormantShifter.swift
2. Update `updateVocalTractLength()` in AudioEngine (lines 557-565)
3. Process audio through VocalTractLengthModifier
4. Create presets for different character voices

**Expected Outcome**: Realistic character voice transformations

#### Task 3.3: Optimize for Real-time Performance (Day 4-5)
**Steps:**
1. Use `RealtimeFormantShifter` class for low-latency processing
2. Profile with Instruments to check CPU usage
3. Adjust frame sizes and hop sizes for optimal latency
4. Add CPU usage monitoring to UI
5. Test on older devices (iPhone 12, SE)

**Expected Outcome**: <10ms added latency for formant processing

---

### 📋 PHASE 4: PERFORMANCE OPTIMIZATION (Week 4) - Priority: MEDIUM

**Goal**: Reduce latency, optimize CPU usage

#### Task 4.1: Optimize Audio Processing Chain (Day 1-2)
**Files to modify:**
- Modify: `VoiceChangerPro/Core/Audio/Engine/VoiceAudioEngine.swift`

**Steps:**
1. Review signal chain for unnecessary conversions
2. Reduce buffer sizes where possible (currently 1024, try 512)
3. Use concurrent queues for parallel processing
4. Pre-allocate all buffers
5. Cache audio format conversions

**Expected Outcome**: Target <5ms total latency

#### Task 4.2: Add Performance Monitoring (Day 2-3)
**Steps:**
1. Add CPU usage tracking
2. Add memory usage tracking
3. Add real-time latency measurement
4. Display metrics in UI during development
5. Add performance tests

**Expected Outcome**: Real-time visibility into performance metrics

---

### 📋 PHASE 5: ENHANCED FEATURES (Week 5-6) - Priority: MEDIUM

**Goal**: Add voice activity detection, pitch detection, preset morphing

#### Task 5.1: Implement Voice Activity Detection (Day 1-2)
**Steps:**
1. Create `VoiceActivityDetector` class from improvement plan
2. Integrate into VoiceProcessor
3. Use for automatic noise gating
4. Update UI to show VAD status
5. Add threshold controls

#### Task 5.2: Add Real-time Pitch Detection (Day 3-4)
**Steps:**
1. Create `PitchDetector` class from improvement plan
2. Integrate into VoiceProcessor
3. Display detected pitch in analysis view
4. Use for pitch correction features

#### Task 5.3: Implement Preset Morphing (Day 5-6)
**Steps:**
1. Create `PresetMorphing` class from improvement plan
2. Add XY pad for morphing between presets
3. Save morphed presets
4. Animate transitions between presets

---

### 📋 PHASE 6: COMPREHENSIVE TESTING (Week 7) - Priority: HIGH

**Goal**: Ensure stability and correctness

#### Task 6.1: Add Unit Tests (Day 1-3)
**Files to create:**
- Create: `VoiceChangerProTests/AudioEngineTests.swift`
- Create: `VoiceChangerProTests/FFTProcessorTests.swift`
- Create: `VoiceChangerProTests/FormantShifterTests.swift`

**Steps:**
1. Copy test file from improvement files
2. Adapt tests to your implementation
3. Add tests for:
   - FFT processing accuracy
   - Formant shifting quality
   - Buffer pool recycling
   - Error handling
   - Preset management
4. Achieve >80% code coverage

#### Task 6.2: Performance Tests (Day 3-4)
**Steps:**
1. Add performance benchmarks
2. Test on multiple devices
3. Measure memory usage over time
4. Test for memory leaks with Instruments
5. Document performance characteristics

#### Task 6.3: Integration Tests (Day 4-5)
**Steps:**
1. Test full audio processing pipeline
2. Test recording workflow
3. Test playback with effects
4. Test preset switching
5. Test error recovery

---

### 📋 PHASE 7: UI/UX ENHANCEMENTS (Week 8) - Priority: LOW

**Goal**: Polish user interface and experience

#### Task 7.1: Enhanced Visualizations (Day 1-3)
**Steps:**
1. Add 3D spectrogram view
2. Add formant visualization
3. Add pitch tracking display
4. Improve waveform visualization
5. Add animations

#### Task 7.2: Gesture Controls (Day 3-4)
**Steps:**
1. Add XY pad for pitch/formant control
2. Add pinch gesture for effect intensity
3. Add haptic feedback
4. Polish animations

#### Task 7.3: Accessibility (Day 4-5)
**Steps:**
1. Add VoiceOver support
2. Add adjustable actions
3. Test with accessibility tools
4. Add voice prompts for status

---

## Implementation Guidelines

### Before Starting Each Phase

1. **Create a Git Branch**: `git checkout -b phase-X-description`
2. **Review Requirements**: Read the phase goals and tasks
3. **Backup Current State**: Commit all changes
4. **Run Tests**: Ensure current tests pass

### During Implementation

1. **Follow Code Style**: Match existing Swift conventions
2. **Comment Complex Logic**: Especially audio processing algorithms
3. **Test Incrementally**: Don't wait until the end
4. **Commit Often**: Small, logical commits
5. **Document Changes**: Update this file with notes

### After Completing Each Phase

1. **Run All Tests**: Ensure nothing broke
2. **Test on Device**: Don't rely on simulator
3. **Profile Performance**: Use Instruments
4. **Update Documentation**: Record any deviations from plan
5. **Merge Branch**: After review and testing

---

## Priority Order for Maximum Impact

If you need to prioritize based on time constraints:

### Must-Have (Complete First)
1. **Phase 1**: Critical fixes - prevents crashes
2. **Phase 3**: Advanced formant processing - core feature improvement
3. **Phase 6**: Testing - ensures stability

### Should-Have (Complete Second)
4. **Phase 2**: Architecture refactoring - code quality
5. **Phase 4**: Performance optimization - user experience

### Nice-to-Have (Complete If Time Permits)
6. **Phase 5**: Enhanced features - competitive advantage
7. **Phase 7**: UI/UX enhancements - polish

---

## Risk Mitigation

### Potential Issues and Solutions

**Issue**: Real-time formant shifting too CPU intensive
- **Solution**: Use RealtimeFormantShifter with smaller frame sizes
- **Fallback**: Offer quality/latency trade-off setting

**Issue**: Buffer pool causes audio glitches
- **Solution**: Pre-allocate larger pool, test extensively
- **Fallback**: Revert to standard allocation temporarily

**Issue**: MVVM refactoring breaks existing features
- **Solution**: Implement incrementally, one view at a time
- **Fallback**: Keep parallel implementations during transition

**Issue**: Tests fail on older devices
- **Solution**: Add device-specific performance profiles
- **Fallback**: Disable advanced features on old hardware

---

## Success Metrics

### Phase 1 Success
- [ ] Zero crashes in 1-hour stress test
- [ ] Memory usage stable over time
- [ ] All errors handled gracefully

### Phase 3 Success
- [ ] Formant shift without pitch artifacts
- [ ] Latency <10ms for formant processing
- [ ] Character voices sound realistic

### Phase 4 Success
- [ ] Total latency <5ms on iPhone 14+
- [ ] CPU usage <30% on iPhone 12
- [ ] Battery drain comparable to music apps

### Phase 6 Success
- [ ] >80% code coverage
- [ ] All critical paths tested
- [ ] Zero known bugs

---

## Next Steps

1. **Read Through This Plan**: Understand the full scope
2. **Ask Questions**: Clarify anything unclear
3. **Start Phase 1, Task 1.1**: Replace FFT implementation
4. **Update This Document**: Add notes as you progress

---

## Notes Section

*Use this section to track progress, issues encountered, and decisions made during implementation.*

### Phase 1 Progress
- [ ] Task 1.1: FFT Replacement - Status: Not Started
- [ ] Task 1.2: Error Handling - Status: Not Started
- [ ] Task 1.3: Buffer Pooling - Status: Not Started

### Phase 2 Progress
- [ ] Task 2.1: File Reorganization - Status: Not Started
- [ ] Task 2.2: MVVM Implementation - Status: Not Started

### Phase 3 Progress
- [ ] Task 3.1: FormantShifter Integration - Status: Not Started
- [ ] Task 3.2: Vocal Tract Processing - Status: Not Started
- [ ] Task 3.3: Performance Optimization - Status: Not Started

*Continue updating as you progress...*
