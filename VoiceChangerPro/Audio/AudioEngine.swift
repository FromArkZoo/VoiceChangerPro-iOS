import AVFoundation
import Accelerate
import Foundation

// MARK: - Audio Constants

/// Centralized audio constants to avoid magic numbers throughout the codebase
enum AudioConstants {
    // Sample rates
    static let defaultSampleRate: Double = 44100
    static let analysisSampleRate: Float = 48000

    // Buffer sizes
    static let fftLength: Int = 1024
    static let analysisFFTLength: Int = 2048
    static let tapBufferSize: UInt32 = 1024
    static let circularBufferSize: Int = 8192
    static let waveformSampleCount: Int = 512
    static let spectrumBinCount: Int = 64

    // Latency settings
    static let ultraLowLatencyDuration: Double = 0.0021  // ~2ms

    // Level metering
    static let minimumLevel: Float = 0.000001
    static let defaultSpectrumValue: Float = -80.0
    static let levelUpdateInterval: TimeInterval = 1.0 / 15.0  // 15 Hz updates

    // Pitch processing
    static let defaultPitchOverlap: Float = 8.0
    static let maxPitchShiftSemitones: Float = 12.0

    // Voice analysis
    static let minFundamentalFrequency: Float = 80.0
    static let maxFundamentalFrequency: Float = 400.0
    static let hopSize: Int = 512

    // Spectrogram
    static let spectrogramMaxFrames: Int = 100
}

/// EQ frequency constants
enum EQConstants {
    // User EQ bands
    static let bassFrequency: Float = 80
    static let midFrequency: Float = 1000
    static let trebleFrequency: Float = 8000
    static let defaultBandwidth: Float = 1.0

    // Formant frequencies for vocal modification
    static let formantF1: Float = 700
    static let formantF2: Float = 1500
    static let formantF3: Float = 2500
    static let formantBandwidth: Float = 0.5
}

/// Volume and gain constants
enum VolumeConstants {
    static let defaultMasterVolume: Float = 2.5
    static let maxMasterVolume: Float = 5.0
    static let defaultBitDepth: Float = 16.0
}

class VoiceChangerAudioEngine: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private var outputNode: AVAudioOutputNode
    private var playerNode: AVAudioPlayerNode
    private var mixerNode: AVAudioMixerNode       // Output mixer

    // Custom DSP pipeline (Phase 1B): input tap writes into a ring buffer;
    // sourceNode's render block pulls from the ring, runs dspChain in-place,
    // then writes to the output ABL. inputNode is NOT connected to the graph —
    // only tapped. This avoids AVAudioEngine's format-converter-in-input-chain
    // assertion that Phase 1 ran into with the built-in effect units.
    private var sourceNode: AVAudioSourceNode!
    private var ringBuffer: AudioRingBuffer!
    private var dspChain: DSPChain!

    // Voice processing parameters
    @Published var pitchShift: Float = 0.0 { didSet { updatePitchShift() } }
    @Published var formantShift: Float = 1.0 { didSet { updateFormantShift() } }
    @Published var timeStretch: Float = 1.0 { didSet { updateTimeStretch() } }
    @Published var vocalTractLength: Float = 1.0 { didSet { updateVocalTractLength() } }
    @Published var noiseReduction: Float = 0.0 { didSet { updateNoiseReduction() } }
    @Published var masterVolume: Float = 2.5 { didSet { updateMasterVolume() } }
    @Published var bassGain: Float = 0.0 { didSet { updateEQ() } }
    @Published var midGain: Float = 0.0 { didSet { updateEQ() } }
    @Published var trebleGain: Float = 0.0 { didSet { updateEQ() } }
    @Published var reverbAmount: Float = 0.0 { didSet { updateReverb() } }
    @Published var ringModRate: Float = 0.0 { didSet { updateRingMod() } }
    @Published var ringModMix: Float = 0.0 { didSet { updateRingMod() } }
    @Published var tremoloRate: Float = 0.0 { didSet { updateTremolo() } }
    @Published var tremoloDepth: Float = 0.0 { didSet { updateTremolo() } }
    @Published var bitDepth: Float = 16.0 { didSet { updateBitDepth() } }

    // Audio level monitoring
    @Published var inputLevel: Float = 0.0
    @Published var outputLevel: Float = 0.0
    @Published var isProcessing: Bool = false

    // Processing state with error handling
    @Published var processingState: ProcessingState = .idle
    @Published var lastError: AudioEngineError?

    // Recording and playback
    @Published var isRecording: Bool = false
    @Published var isPlayingBack: Bool = false
    @Published var playbackProgress: Double = 0.0

    // Headphone detection
    @Published var isHeadphonesConnected: Bool = false
    @Published var monitoringMode: MonitoringMode = .speaker

    private var audioRecorder: AudioRecorder?
    private var recordingFile: AVAudioFile?
    private var playbackFile: AVAudioFile?
    private var playbackPlayerNode: AVAudioPlayerNode?

    // Monitoring modes
    enum MonitoringMode {
        case speaker        // Output to speaker (feedback risk)
        case headphones     // Output to headphones (safe)
        case direct         // Direct monitoring only (no output)
    }


    // Analysis data for visualization
    @Published var waveformData: [Float] = []
    @Published var spectrumData: [Float] = []

    private var levelTimer: Timer?

    private var isSetup = false

    // Optimized FFT processor
    private var fftProcessor: OptimizedFFTProcessor?

    // CRITICAL: Store the processing format for consistent audio chain
    private var processingFormat: AVAudioFormat?
    private var recordingFormat: AVAudioFormat?

    /// Called on the main queue after a recording finishes (either via explicit
    /// stopRecording() or implicitly when stopProcessing() is called mid-record).
    /// Consumer (ContentView) uses this to register the file with RecordingManager.
    var onRecordingFinished: ((URL) -> Void)?

    // Thread safety
    private let engineLock = NSLock()

    // Dedicated queue for FFT analysis (off audio thread)
    private let analysisQueue = DispatchQueue(label: "com.voicechanger.analysis", qos: .userInitiated)

    // Pre-allocated buffer for waveform data to avoid audio thread allocations
    private var waveformBuffer = [Float](repeating: 0, count: AudioConstants.waveformSampleCount)

    // Throttling for UI updates
    private var lastLevelUpdateTime: CFAbsoluteTime = 0
    private var lastSpectrumUpdateTime: CFAbsoluteTime = 0
    private let levelUpdateInterval: CFAbsoluteTime = 1.0 / 15.0  // 15 Hz
    private let spectrumUpdateInterval: CFAbsoluteTime = 1.0 / 10.0  // 10 Hz
    
    init() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        outputNode = audioEngine.outputNode
        playerNode = AVAudioPlayerNode()
        mixerNode = AVAudioMixerNode()       // Output mixer

        // Initialize recorder
        audioRecorder = AudioRecorder()

        // Initialize FFT processor
        fftProcessor = OptimizedFFTProcessor(fftLength: 1024)

        setupHeadphoneDetection()
    }
    
    deinit {
        print("🔄 AudioEngine deinit called")
        
        // Clean up resources safely
        levelTimer?.invalidate()
        levelTimer = nil
        
        // Remove notification observers
        #if os(iOS)
        NotificationCenter.default.removeObserver(self)
        #endif
        
        // Stop engine if running
        if audioEngine.isRunning {
            print("   Stopping audio engine...")
            audioEngine.stop()
        }
        
        // Remove taps safely (only if engine exists and nodes are attached)
        do {
            if audioEngine.attachedNodes.contains(inputNode) {
                inputNode.removeTap(onBus: 0)
                print("   ✓ Input tap removed")
            }
        } catch {
            print("   ⚠️ Could not remove input tap: \(error)")
        }
        
        do {
            if audioEngine.attachedNodes.contains(mixerNode) {
                mixerNode.removeTap(onBus: 0)
                print("   ✓ Mixer tap removed")
            }
        } catch {
            print("   ⚠️ Could not remove mixer tap: \(error)")
        }
        
        print("✅ AudioEngine deallocated")
    }

    private func setupHeadphoneDetection() {
        #if os(iOS)
        // Check initial headphone state
        checkHeadphoneStatus()

        // Listen for route changes (headphones plugged/unplugged)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        // Listen for audio session interruptions (calls, alarms, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        #endif
    }

    @objc private func handleRouteChange(notification: Notification) {
        checkHeadphoneStatus()
    }
    
    @objc private func handleInterruption(notification: Notification) {
        #if os(iOS)
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began - stop processing
            print("⚠️ Audio session interrupted")
            if isProcessing {
                stopProcessing()
            }
            
        case .ended:
            // Interruption ended - check if we should resume
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
                print("ℹ️ Audio session interruption ended - can resume")
                // Don't auto-resume - let user manually restart
                // This prevents unexpected behavior
            }
            
        @unknown default:
            break
        }
        #endif
    }

    private func checkHeadphoneStatus() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs

        let isHeadphones = outputs.contains { output in
            output.portType == .headphones ||
            output.portType == .bluetoothA2DP ||
            output.portType == .bluetoothLE ||
            output.portType == .bluetoothHFP
        }

        DispatchQueue.main.async {
            self.isHeadphonesConnected = isHeadphones
            self.monitoringMode = isHeadphones ? .headphones : .speaker

            if isHeadphones {
                print("✓ Headphones connected - Safe mode")
            } else {
                print("⚠️ No headphones - Feedback risk with speaker")
            }
        }
        #endif
    }

    private func setupIfNeeded() throws {
        engineLock.lock()
        defer { engineLock.unlock() }
        
        guard !isSetup else { 
            print("   ℹ️ Audio already setup, skipping")
            return 
        }
        
        print("🔄 Setting up audio engine for first time...")
        
        try setupAudioSession()
        setupAudioGraph()
        isSetup = true
    }

    private func setupAudioSession() throws {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()

            // Configure based on headphone status
            if isHeadphonesConnected {
                // With headphones: Can use higher quality, no feedback risk
                // Allow all Bluetooth profiles for maximum compatibility
                try audioSession.setCategory(.playAndRecord,
                                           mode: .default,  // Higher quality than voiceChat
                                           options: [.allowBluetoothA2DP, .allowBluetoothHFP])
                print("🎧 Headphones mode: High quality, no echo cancellation needed")
            } else {
                // Without headphones: Use aggressive echo cancellation
                try audioSession.setCategory(.playAndRecord,
                                           mode: .voiceChat,  // Aggressive echo cancellation
                                           options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowBluetoothHFP])

                // Enable echo cancellation if available (iOS 18.2+)
                if #available(iOS 18.2, *) {
                    if audioSession.isEchoCancelledInputAvailable {
                        try audioSession.setPrefersEchoCancelledInput(true)
                        print("🔊 Speaker mode: Echo cancellation enabled (iOS 18.2+)")
                    }
                } else {
                    print("🔊 Speaker mode: Using voiceChat echo cancellation")
                }
            }

            // Set preferred sample rate BEFORE activating
            // Use 44100 Hz which is more commonly supported
            try audioSession.setPreferredSampleRate(44100)

            // Buffer duration - ultra-low latency mode
            let bufferDuration: TimeInterval = 0.0021  // ~2ms for ultra-low latency
            try audioSession.setPreferredIOBufferDuration(bufferDuration)

            // Now activate the session
            try audioSession.setActive(true)

            print("Audio session sample rate: \(audioSession.sampleRate)")
            print("Audio session IO buffer duration: \(audioSession.ioBufferDuration)")
            print("Audio session mode: \(audioSession.mode.rawValue)")
        } catch {
            print("Audio session setup failed: \(error)")
            throw AudioEngineError.audioSessionConfigurationFailed(error)
        }
        #endif
    }

    private func setupPlaybackAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()

            // Use playback mode for recorded audio playback
            try audioSession.setCategory(.playback,
                                       mode: .default,
                                       options: [.mixWithOthers])

            try audioSession.setActive(true)
            print("Playback audio session configured")
        } catch {
            print("Playback audio session setup failed: \(error)")
        }
        #endif
    }

    private func setupAudioGraph() {
        print("🔄 Setting up audio graph (pull pipeline)...")

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()

        inputNode = audioEngine.inputNode
        outputNode = audioEngine.outputNode

        let inputFormat = inputNode.inputFormat(forBus: 0)
        print("   Input format: \(inputFormat)")

        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            print("❌ Invalid input format")
            return
        }

        // The pull pipeline operates on mono Float32 at the input's sample rate.
        // AVAudioMixerNode at the end will convert to whatever the output device needs.
        let pipelineFormat = AVAudioFormat(standardFormatWithSampleRate: inputFormat.sampleRate,
                                           channels: 1) ?? inputFormat
        processingFormat = pipelineFormat
        print("   Pipeline format: \(pipelineFormat)")

        // (Re)allocate ring buffer and DSP chain sized for this format.
        let capacity = max(AudioConstants.circularBufferSize, Int(pipelineFormat.sampleRate * 0.25))
        ringBuffer = AudioRingBuffer(capacity: capacity)
        dspChain = DSPChain(sampleRate: pipelineFormat.sampleRate)
        syncDSPChainFromPublished()

        // Render block: consumer of the ring buffer. Called on the audio thread.
        // Must be allocation-free. Captures `ringBuffer` and `dspChain` unowned.
        let rb = ringBuffer!
        let chain = dspChain!
        let renderBlock: AVAudioSourceNodeRenderBlock = { _, _, frameCount, audioBufferList in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            // Single channel pipeline: one buffer, write into .mData as Float32.
            guard let mData = abl[0].mData else { return noErr }
            let dst = mData.assumingMemoryBound(to: Float.self)
            let requested = Int(frameCount)

            let got = rb.read(dst, count: requested)
            if got < requested {
                // Underrun — fill the rest with silence rather than glitching garbage.
                let silenceStart = dst.advanced(by: got)
                silenceStart.update(repeating: 0, count: requested - got)
            }
            chain.process(dst, frameCount: requested)
            return noErr
        }

        sourceNode = AVAudioSourceNode(format: pipelineFormat, renderBlock: renderBlock)

        // Attach pipeline nodes.
        if audioEngine.attachedNodes.contains(mixerNode) { audioEngine.detach(mixerNode) }
        audioEngine.attach(sourceNode)
        audioEngine.attach(mixerNode)

        // Pipeline graph. inputNode is intentionally NOT connected — only tapped.
        audioEngine.connect(sourceNode, to: mixerNode, format: pipelineFormat)
        audioEngine.connect(mixerNode, to: outputNode, format: nil)
        print("   ✓ Graph: [inputNode(tap only)] → ringBuffer → sourceNode → mixerNode → outputNode")

        // Install input tap (producer). Format is whatever the mic offers natively —
        // no downstream graph connection means no implicit converter, no crash.
        inputNode.removeTap(onBus: 0)
        // Tap buffer size is advisory on iOS; pick a size close to our IO buffer.
        let tapBufferSize: AVAudioFrameCount = AudioConstants.tapBufferSize
        inputNode.installTap(onBus: 0, bufferSize: tapBufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.handleInputTapBuffer(buffer)
        }

        // Output tap on mixer (level meter + recording). Use the mixer's actual
        // output format rather than pipelineFormat — iOS sets the mixer's output
        // format from the downstream connection (outputNode), not our input side,
        // so passing a mismatched format to installTap silently drops buffers or
        // hands us frames in the wrong layout.
        mixerNode.removeTap(onBus: 0)
        let mixerOutputFormat = mixerNode.outputFormat(forBus: 0)
        recordingFormat = mixerOutputFormat
        mixerNode.installTap(onBus: 0, bufferSize: tapBufferSize, format: mixerOutputFormat) { [weak self] buffer, _ in
            self?.processOutputBuffer(buffer)
            if let self = self, self.isRecording {
                do {
                    try self.audioRecorder?.writeBuffer(buffer)
                } catch {
                    print("⚠️ Recording buffer write failed: \(error)")
                    DispatchQueue.main.async { _ = self.stopRecording() }
                }
            }
        }

        print("✅ Audio graph configured successfully")
    }

    /// Convert the incoming tap buffer (which may be multichannel or at a different
    /// rate than the pipeline declares) into mono Float32 at the pipeline's rate and
    /// push into the ring buffer. Runs on the audio thread.
    private func handleInputTapBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }

        // Mic is typically mono already; if not, downmix to mono by averaging.
        if buffer.format.channelCount == 1 {
            let _ = ringBuffer?.write(channelData[0], count: frames)
        } else {
            // Pre-allocated scratch for occasional stereo mics. Allocation on
            // audio thread is unavoidable here without threading more state;
            // acceptable as a one-off downmix until we adopt a SourceNode-native
            // input AU in a later pass.
            var mono = [Float](repeating: 0, count: frames)
            let chans = Int(buffer.format.channelCount)
            mono.withUnsafeMutableBufferPointer { m in
                for f in 0..<frames {
                    var sum: Float = 0
                    for c in 0..<chans { sum += channelData[c][f] }
                    m[f] = sum / Float(chans)
                }
                _ = ringBuffer?.write(m.baseAddress!, count: frames)
            }
        }

        // Also update input-level meter from the mono sum (throttled in callee).
        processInputBuffer(buffer)
    }

    /// Push all @Published effect parameters into the DSP chain. Call whenever the
    /// chain is freshly constructed (e.g. after setupAudioGraph).
    private func syncDSPChainFromPublished() {
        guard let chain = dspChain else { return }
        chain.pitchShiftSemitones = pitchShift
        chain.timeStretch = timeStretch
        chain.formantShift = formantShift
        chain.vocalTractLength = vocalTractLength
        chain.noiseReduction = noiseReduction
        chain.bassGain = bassGain
        chain.midGain = midGain
        chain.trebleGain = trebleGain
        chain.reverbAmount = reverbAmount
        chain.ringModRate = ringModRate
        chain.ringModMix = ringModMix
        chain.tremoloRate = tremoloRate
        chain.tremoloDepth = tremoloDepth
        chain.bitDepth = bitDepth
    }

    private func processInputBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        // Throttle updates to reduce UI overhead
        let currentTime = CFAbsoluteTimeGetCurrent()
        guard currentTime - lastLevelUpdateTime >= levelUpdateInterval else { return }
        lastLevelUpdateTime = currentTime

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0.0
        for channel in 0..<channelCount {
            var channelSum: Float = 0.0
            vDSP_sve(channelData[channel], 1, &channelSum, vDSP_Length(frameLength))
            sum += abs(channelSum)
        }

        let average = sum / Float(frameLength * channelCount)
        let normalizedLevel = 20 * log10(max(average, AudioConstants.minimumLevel))

        DispatchQueue.main.async { [weak self] in
            self?.inputLevel = normalizedLevel
        }
    }

    private func processOutputBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        guard frameLength > 0 else { return }

        let currentTime = CFAbsoluteTimeGetCurrent()

        // Calculate output level (throttled)
        if currentTime - lastLevelUpdateTime >= levelUpdateInterval {
            var sum: Float = 0.0
            for channel in 0..<channelCount {
                var channelSum: Float = 0.0
                vDSP_sve(channelData[channel], 1, &channelSum, vDSP_Length(frameLength))
                sum += abs(channelSum)
            }

            let average = sum / Float(frameLength * channelCount)
            let normalizedLevel = 20 * log10(max(average, AudioConstants.minimumLevel))

            DispatchQueue.main.async { [weak self] in
                self?.outputLevel = normalizedLevel
            }
        }

        // Process visualization data (throttled separately)
        guard currentTime - lastSpectrumUpdateTime >= spectrumUpdateInterval else { return }
        lastSpectrumUpdateTime = currentTime

        // Copy waveform data without allocating on audio thread
        let sampleCount = min(frameLength, AudioConstants.waveformSampleCount)
        let waveformSamples: [Float]

        // Create array from buffer pointer (minimal allocation)
        waveformSamples = Array(UnsafeBufferPointer(start: channelData[0], count: sampleCount))

        // Move FFT processing to analysis queue (off audio thread)
        analysisQueue.async { [weak self] in
            guard let self = self, let fftProcessor = self.fftProcessor else { return }

            // Process spectrum data using FFT
            var spectrum: [Float]
            if frameLength >= AudioConstants.fftLength {
                spectrum = fftProcessor.processSpectrumWithBins(from: waveformSamples, binCount: AudioConstants.spectrumBinCount)
            } else {
                spectrum = Array(repeating: AudioConstants.defaultSpectrumValue, count: AudioConstants.spectrumBinCount)
            }

            DispatchQueue.main.async { [weak self] in
                self?.waveformData = waveformSamples
                self?.spectrumData = spectrum
            }
        }
    }

    // MARK: - Start/Stop Processing

    func startProcessing() throws {
        print("🔄 startProcessing called from thread: \(Thread.current)")
        
        guard !isProcessing else {
            print("⚠️ Already processing, ignoring start request")
            return
        }
        
        print("🔄 Starting audio processing...")
        
        // Check microphone permission first (iOS only)
        #if os(iOS)
        let permissionStatus = AVAudioApplication.shared.recordPermission
        print("   Permission status: \(permissionStatus)")
        
        if permissionStatus == .denied {
            print("❌ Microphone permission denied")
            let error = NSError(domain: "AudioEngine", code: -2,
                               userInfo: [NSLocalizedDescriptionKey: "Microphone access denied. Please enable in Settings."])
            throw AudioEngineError.engineStartFailed(error)
        } else if permissionStatus == .undetermined {
            print("⚠️ Microphone permission not yet requested - will be requested when session activates")
        } else {
            print("✅ Microphone permission granted")
        }
        #endif
        
        do {
            // Setup audio session and graph
            print("🔄 Setting up audio session and graph...")
            try setupIfNeeded()
            
            print("✓ Audio session and graph configured")
            
            // Validate that processing format was set
            guard processingFormat != nil else {
                let error = NSError(domain: "AudioEngine", code: -1, 
                                   userInfo: [NSLocalizedDescriptionKey: "Processing format not initialized"])
                throw AudioEngineError.engineStartFailed(error)
            }
            
            print("🔄 Preparing audio engine...")
            audioEngine.prepare()
            
            print("🔄 Starting audio engine...")
            try audioEngine.start()
            
            DispatchQueue.main.async {
                self.isProcessing = true
                self.processingState = .processing
            }
            
            print("✅ Audio processing started successfully")
            print("   Input format: \(inputNode.inputFormat(forBus: 0))")
            if let format = processingFormat {
                print("   Processing format: \(format)")
            }
            print("   Output format: \(outputNode.outputFormat(forBus: 0))")
            print("   Latency: \(String(format: "%.2f", getLatency() * 1000))ms")
            
        } catch {
            DispatchQueue.main.async {
                self.processingState = .error
                self.lastError = AudioEngineError.engineStartFailed(error)
            }
            
            print("❌ Failed to start audio engine")
            print("   Error: \(error.localizedDescription)")
            
            // Provide detailed error information
            if let nsError = error as NSError? {
                print("   Domain: \(nsError.domain)")
                print("   Code: \(nsError.code)")
                print("   Description: \(nsError.localizedDescription)")
                
                // Check for common issues
                if nsError.code == -10863 {
                    print("   ⚠️ Format issue detected - check audio formats")
                } else if nsError.code == 561015905 {
                    print("   ⚠️ Audio session not configured properly")
                } else if nsError.code == 561145187 {
                    print("   ⚠️ '!pri' - Audio session privacy/permission issue")
                } else if nsError.code == 2003329396 {
                    print("   ⚠️ 'what' - Node attachment or connection issue")
                }
            }
            
            // Clean up on error
            isSetup = false
            
            throw error
        }
    }

    func stopProcessing() {
        engineLock.lock()
        guard isProcessing else {
            engineLock.unlock()
            return
        }

        NSLog("VCP-REC stopProcessing — finalising any active recording")

        if isRecording {
            let url = finishRecordingLocked()
            if let url = url {
                DispatchQueue.main.async { [weak self] in
                    self?.onRecordingFinished?(url)
                }
            }
        }

        print("🔄 Stopping audio processing...")

        // CRITICAL: Remove taps BEFORE stopping engine
        print("   Removing audio taps...")
        inputNode.removeTap(onBus: 0)
        print("   ✓ Input tap removed")

        mixerNode.removeTap(onBus: 0)
        print("   ✓ Mixer tap removed")
        
        // Stop the engine
        if audioEngine.isRunning {
            print("   Stopping engine...")
            audioEngine.stop()
            print("   ✓ Engine stopped")
        }

        // Reset setup flag so next start will reconfigure
        isSetup = false

        engineLock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.isProcessing = false
            self?.processingState = .idle
        }

        print("✅ Audio processing stopped")
    }

    // MARK: - Parameter Updates

    private func updatePitchShift() {
        NSLog(String(format: "VCP-PITCH-UPDATE semitones=%.2f dspChain=%@",
                     pitchShift, dspChain == nil ? "nil" : "live"))
        dspChain?.pitchShiftSemitones = pitchShift
    }

    private func updateFormantShift() {
        dspChain?.formantShift = formantShift
    }

    private func updateTimeStretch() {
        dspChain?.timeStretch = timeStretch
    }

    private func updateVocalTractLength() {
        dspChain?.vocalTractLength = vocalTractLength
    }

    private func updateNoiseReduction() {
        dspChain?.noiseReduction = noiseReduction
    }

    private func updateMasterVolume() {
        mixerNode.outputVolume = masterVolume
    }

    private func updateEQ() {
        NSLog(String(format: "VCP-EQ-UPDATE bass=%.2f mid=%.2f treble=%.2f dspChain=%@",
                     bassGain, midGain, trebleGain, dspChain == nil ? "nil" : "live"))
        dspChain?.bassGain = bassGain
        dspChain?.midGain = midGain
        dspChain?.trebleGain = trebleGain
    }

    private func updateReverb() {
        NSLog(String(format: "VCP-REVERB-UPDATE amount=%.2f dspChain=%@",
                     reverbAmount, dspChain == nil ? "nil" : "live"))
        dspChain?.reverbAmount = reverbAmount
    }

    private func updateRingMod() {
        NSLog(String(format: "VCP-RINGMOD-UPDATE rate=%.2f mix=%.2f dspChain=%@",
                     ringModRate, ringModMix, dspChain == nil ? "nil" : "live"))
        dspChain?.ringModRate = ringModRate
        dspChain?.ringModMix = ringModMix
    }

    private func updateTremolo() {
        NSLog(String(format: "VCP-TREMOLO-UPDATE rate=%.2f depth=%.2f dspChain=%@",
                     tremoloRate, tremoloDepth, dspChain == nil ? "nil" : "live"))
        dspChain?.tremoloRate = tremoloRate
        dspChain?.tremoloDepth = tremoloDepth
    }

    private func updateBitDepth() {
        dspChain?.bitDepth = bitDepth
    }

    func resetToFactory() {
        pitchShift = 0.0
        formantShift = 1.0
        timeStretch = 1.0
        vocalTractLength = 1.0
        noiseReduction = 0.0
        masterVolume = 2.5
        bassGain = 0.0
        midGain = 0.0
        trebleGain = 0.0
        reverbAmount = 0.0
        ringModRate = 0.0
        ringModMix = 0.0
        tremoloRate = 0.0
        tremoloDepth = 0.0
        bitDepth = 16.0
    }

    func getLatency() -> TimeInterval {
        return audioEngine.outputNode.presentationLatency +
               audioEngine.inputNode.presentationLatency
    }

    // MARK: - Recording Functions

    func startRecording() {
        guard isProcessing, !isRecording else { return }

        do {
            // Recording must use the exact format the mixer tap delivers; otherwise
            // AVAudioFile rejects the buffer at write time.
            let format = recordingFormat ?? mixerNode.outputFormat(forBus: 0)
            recordingFile = try audioRecorder?.startRecording(format: format)
            isRecording = true
            NSLog("VCP-REC startRecording format=\(format)")
        } catch {
            NSLog("VCP-REC startRecording FAILED: \(error.localizedDescription)")
        }
    }

    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        return finishRecordingLocked()
    }

    /// Core recording finaliser. Safe to call whether engineLock is held or not —
    /// AudioRecorder is independent of engine state. Does NOT remove the mixer
    /// tap (that stays installed for level metering / future Record sessions
    /// during the same Start cycle).
    @discardableResult
    private func finishRecordingLocked() -> URL? {
        guard isRecording else { return nil }
        isRecording = false
        let url = audioRecorder?.stopRecording()
        NSLog("VCP-REC stopRecording file=\(url?.lastPathComponent ?? "<nil>")")
        return url
    }

    func cancelRecording() {
        guard isRecording else { return }
        
        isRecording = false
        audioRecorder?.cancelRecording()
        
        print("Recording cancelled")
    }

    func getRecordingDuration() -> TimeInterval {
        return audioRecorder?.recordingDuration ?? 0
    }

    // MARK: - Playback Functions

    func startPlayback(url: URL) {
        guard !isPlayingBack else { return }
        
        do {
            // Stop live processing if active
            let wasProcessing = isProcessing
            if wasProcessing {
                stopProcessing()
            }
            
            // Setup audio session for playback only (no recording)
            setupPlaybackAudioSession()
            
            // Load the audio file
            playbackFile = try AVAudioFile(forReading: url)
            guard let file = playbackFile else { return }
            
            let fileFormat = file.processingFormat
            
            // Create and attach playback player node
            playbackPlayerNode = AVAudioPlayerNode()
            guard let player = playbackPlayerNode else { return }
            
            audioEngine.attach(player)
            audioEngine.attach(mixerNode)

            guard let standardFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: fileFormat.sampleRate,
                channels: fileFormat.channelCount,
                interleaved: false
            ) else {
                print("Failed to create playback format")
                return
            }

            audioEngine.connect(player, to: mixerNode, format: standardFormat)
            audioEngine.connect(mixerNode, to: outputNode, format: nil)
            
            // Prepare and start the engine
            audioEngine.prepare()
            try audioEngine.start()
            
            // Schedule the file for playback
            player.scheduleFile(file, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.stopPlayback()
                }
            }
            
            // Start playback
            player.play()
            isPlayingBack = true
            
            // Monitor playback progress
            startPlaybackProgressMonitoring(duration: Double(file.length) / file.fileFormat.sampleRate)
            
            print("✅ Playback started: \(url.lastPathComponent)")
            print("File format: \(fileFormat)")
            print("Processing format: \(standardFormat)")
            
        } catch {
            print("❌ Failed to start playback: \(error)")
            if let nsError = error as NSError? {
                print("Error domain: \(nsError.domain)")
                print("Error code: \(nsError.code)")
                print("Error description: \(nsError.localizedDescription)")
            }
        }
    }

    func stopPlayback() {
        guard isPlayingBack else { return }

        // Stop playback first
        playbackPlayerNode?.stop()

        // Stop the engine safely
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        // Cleanup nodes on a background queue to avoid blocking
        let player = playbackPlayerNode
        let nodesToCleanup: [AVAudioNode] = [mixerNode]

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }

            // Now safely disconnect and detach nodes
            if let player = player {
                if self.audioEngine.attachedNodes.contains(player) {
                    self.audioEngine.disconnectNodeInput(player)
                    self.audioEngine.detach(player)
                }
            }

            // Disconnect and detach effects nodes if they're still attached
            for node in nodesToCleanup {
                if self.audioEngine.attachedNodes.contains(node) {
                    self.audioEngine.disconnectNodeInput(node)
                    self.audioEngine.detach(node)
                }
            }

            print("✅ Playback nodes cleaned up")
        }

        playbackPlayerNode = nil
        playbackFile = nil
        isPlayingBack = false
        playbackProgress = 0.0
        isSetup = false

        // Stop progress monitoring
        levelTimer?.invalidate()
        levelTimer = nil

        print("✅ Playback stopped safely")
    }

    private func startPlaybackProgressMonitoring(duration: Double) {
        levelTimer?.invalidate()
        
        var elapsed: Double = 0
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlayingBack else { return }
            
            elapsed += 0.1
            self.playbackProgress = min(elapsed / duration, 1.0)
            
            if elapsed >= duration {
                self.levelTimer?.invalidate()
            }
        }
    }
}

// MARK: - Supporting Types

enum ProcessingState {
    case idle
    case processing
    case error
}

enum AudioEngineError: Error {
    case audioSessionConfigurationFailed(Error)
    case engineStartFailed(Error)
    case recordingFailed(Error)
    case playbackFailed(Error)
}

