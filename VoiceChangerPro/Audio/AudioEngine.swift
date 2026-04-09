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

    // Audio units for effects
    private var pitchUnit: AVAudioUnitTimePitch
    private var reverbUnit: AVAudioUnitReverb
    private var userEqUnit: AVAudioUnitEQ  // User tone controls (bass/mid/treble)
    private var eqUnit: AVAudioUnitEQ      // Formant & vocal tract processing
    private var distortionUnit: AVAudioUnitDistortion

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

        // Initialize audio units
        pitchUnit = AVAudioUnitTimePitch()
        reverbUnit = AVAudioUnitReverb()
        userEqUnit = AVAudioUnitEQ(numberOfBands: 3)  // User tone controls
        eqUnit = AVAudioUnitEQ(numberOfBands: 3)      // Formant processing
        distortionUnit = AVAudioUnitDistortion()

        // Configure pitch unit for low latency
        pitchUnit.pitch = 0.0
        pitchUnit.rate = 1.0
        pitchUnit.overlap = 8.0 // Default overlap for balance between quality and latency

        // Initialize recorder
        audioRecorder = AudioRecorder()

        // Initialize FFT processor
        fftProcessor = OptimizedFFTProcessor(fftLength: 1024)

        setupEQ()
        setupReverb()
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
        print("🔄 Setting up audio graph...")
        
        // CRITICAL: Stop engine if running before reconfiguring
        if audioEngine.isRunning {
            print("   ⚠️ Stopping running engine before reconfiguration")
            audioEngine.stop()
        }
        
        // Reset the engine to clear any previous state
        audioEngine.reset()
        print("   ✓ Audio engine reset")
        
        // IMPORTANT: After reset, we need to get fresh node references
        // The reset() clears the graph but nodes remain attached
        inputNode = audioEngine.inputNode
        outputNode = audioEngine.outputNode
        print("   ✓ Fresh node references obtained")
        
        // Get the input format AFTER reset
        let inputFormat = inputNode.inputFormat(forBus: 0)
        print("   Input format: \(inputFormat)")
        print("   Sample rate: \(inputFormat.sampleRate), Channels: \(inputFormat.channelCount)")
        
        // Validate input format
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            print("❌ Invalid input format detected")
            return
        }

        // CRITICAL FIX: Use the EXACT input format, don't create a new one
        // This prevents ANY format conversion from happening
        let standardFormat = inputFormat
        
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        print("   Hardware sample rate: \(audioSession.sampleRate)")
        print("   Using input format directly (no conversion): \(standardFormat)")
        #endif

        processingFormat = standardFormat
        print("   Processing format: \(standardFormat)")

        // Attach all nodes
        print("🔄 Attaching audio nodes...")
        
        // Detach nodes first if they're already attached (prevents crash)
        let nodesToAttach = [pitchUnit, userEqUnit, eqUnit, distortionUnit, reverbUnit, mixerNode]
        for node in nodesToAttach {
            if audioEngine.attachedNodes.contains(node) {
                audioEngine.detach(node)
            }
        }
        
        // Now attach all nodes
        audioEngine.attach(pitchUnit)
        audioEngine.attach(userEqUnit)
        audioEngine.attach(eqUnit)
        audioEngine.attach(distortionUnit)
        audioEngine.attach(reverbUnit)
        audioEngine.attach(mixerNode)
        print("   ✓ All nodes attached")

        // Connect audio chain directly (no format conversion needed)
        // Input -> Pitch -> User EQ -> Formant EQ -> Distortion -> Reverb -> Mixer -> Output
        print("🔄 Connecting audio chain...")
        
        // CRITICAL: Disconnect all nodes first to ensure clean connections
        print("   Disconnecting any existing connections...")
        audioEngine.disconnectNodeInput(pitchUnit)
        audioEngine.disconnectNodeInput(userEqUnit)
        audioEngine.disconnectNodeInput(eqUnit)
        audioEngine.disconnectNodeInput(distortionUnit)
        audioEngine.disconnectNodeInput(reverbUnit)
        audioEngine.disconnectNodeInput(mixerNode)
        print("   ✓ All nodes disconnected")
        
        // Now make fresh connections
        do {
            audioEngine.connect(inputNode, to: pitchUnit, format: standardFormat)
            print("   ✓ Input -> Pitch")
            
            audioEngine.connect(pitchUnit, to: userEqUnit, format: standardFormat)
            print("   ✓ Pitch -> UserEQ")
            
            audioEngine.connect(userEqUnit, to: eqUnit, format: standardFormat)
            print("   ✓ UserEQ -> EQ")
            
            audioEngine.connect(eqUnit, to: distortionUnit, format: standardFormat)
            print("   ✓ EQ -> Distortion")
            
            audioEngine.connect(distortionUnit, to: reverbUnit, format: standardFormat)
            print("   ✓ Distortion -> Reverb")
            
            audioEngine.connect(reverbUnit, to: mixerNode, format: standardFormat)
            print("   ✓ Reverb -> Mixer")

            // Connect mixer to output (let it auto-convert to output format)
            audioEngine.connect(mixerNode, to: outputNode, format: nil)
            print("   ✓ Mixer -> Output")
        } catch {
            print("❌ Error connecting nodes: \(error)")
            return
        }

        // Setup tap for audio level monitoring on input
        print("🔄 Installing audio taps...")
        
        // Remove any existing taps first
        do {
            inputNode.removeTap(onBus: 0)
            print("   ✓ Removed existing input tap")
        } catch {
            print("   ℹ️ No existing input tap to remove")
        }
        
        // Install input tap
        do {
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: standardFormat) { [weak self] buffer, time in
                self?.processInputBuffer(buffer)
            }
            print("   ✓ Input tap installed")
        } catch {
            print("   ❌ Failed to install input tap: \(error)")
            return
        }

        // Remove any existing output tap
        do {
            mixerNode.removeTap(onBus: 0)
            print("   ✓ Removed existing output tap")
        } catch {
            print("   ℹ️ No existing output tap to remove")
        }
        
        // Install output tap
        do {
            mixerNode.installTap(onBus: 0, bufferSize: 1024, format: standardFormat) { [weak self] buffer, time in
                self?.processOutputBuffer(buffer)

                // If recording, write the processed audio
                if let self = self, self.isRecording {
                    do {
                        try self.audioRecorder?.writeBuffer(buffer)
                    } catch {
                        print("⚠️ Recording buffer write failed: \(error)")
                        // Stop recording on error to prevent corruption
                        DispatchQueue.main.async {
                            _ = self.stopRecording()
                        }
                    }
                }
            }
            print("   ✓ Output tap installed")
        } catch {
            print("   ❌ Failed to install output tap: \(error)")
            return
        }

        print("✅ Audio graph configured successfully")
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
            
            // Prepare and start the engine
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

        print("🔄 Stopping audio processing...")
        
        // CRITICAL: Remove taps BEFORE stopping engine
        print("   Removing audio taps...")
        do {
            inputNode.removeTap(onBus: 0)
            print("   ✓ Input tap removed")
        } catch {
            print("   ⚠️ Input tap removal failed: \(error)")
        }
        
        do {
            mixerNode.removeTap(onBus: 0)
            print("   ✓ Mixer tap removed")
        } catch {
            print("   ⚠️ Mixer tap removal failed: \(error)")
        }
        
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

    private func setupEQ() {
        // Setup user-facing tone controls
        guard userEqUnit.bands.count >= 3 else { return }
        
        // Bass (80 Hz)
        userEqUnit.bands[0].frequency = 80
        userEqUnit.bands[0].bandwidth = 1.0
        userEqUnit.bands[0].gain = 0.0
        userEqUnit.bands[0].bypass = false
        userEqUnit.bands[0].filterType = .parametric
        
        // Mid (1000 Hz)
        userEqUnit.bands[1].frequency = 1000
        userEqUnit.bands[1].bandwidth = 1.0
        userEqUnit.bands[1].gain = 0.0
        userEqUnit.bands[1].bypass = false
        userEqUnit.bands[1].filterType = .parametric
        
        // Treble (8000 Hz)
        userEqUnit.bands[2].frequency = 8000
        userEqUnit.bands[2].bandwidth = 1.0
        userEqUnit.bands[2].gain = 0.0
        userEqUnit.bands[2].bypass = false
        userEqUnit.bands[2].filterType = .parametric
        
        // Setup formant/vocal tract EQ
        guard eqUnit.bands.count >= 3 else { return }
        
        // Formant frequencies for vocal modification
        eqUnit.bands[0].frequency = 700   // F1
        eqUnit.bands[0].bandwidth = 0.5
        eqUnit.bands[0].gain = 0.0
        eqUnit.bands[0].bypass = false
        eqUnit.bands[0].filterType = .parametric
        
        eqUnit.bands[1].frequency = 1500  // F2
        eqUnit.bands[1].bandwidth = 0.5
        eqUnit.bands[1].gain = 0.0
        eqUnit.bands[1].bypass = false
        eqUnit.bands[1].filterType = .parametric
        
        eqUnit.bands[2].frequency = 2500  // F3
        eqUnit.bands[2].bandwidth = 0.5
        eqUnit.bands[2].gain = 0.0
        eqUnit.bands[2].bypass = false
        eqUnit.bands[2].filterType = .parametric
    }

    private func setupReverb() {
        reverbUnit.loadFactoryPreset(.mediumHall)
        reverbUnit.wetDryMix = 0
    }

    private func updatePitchShift() {
        // Pitch shift in cents (-2400 to +2400 = -2 to +2 octaves)
        pitchUnit.pitch = pitchShift * 100
    }

    private func updateFormantShift() {
        // Simulate formant shift using EQ bands
        // Shift formant frequencies up or down
        guard eqUnit.bands.count >= 3 else { return }
        
        let shift = formantShift
        
        // Adjust formant frequencies
        eqUnit.bands[0].frequency = 700 * shift   // F1
        eqUnit.bands[1].frequency = 1500 * shift  // F2
        eqUnit.bands[2].frequency = 2500 * shift  // F3
        
        // Adjust gains to emphasize the shift
        let gainAdjust = (shift - 1.0) * 10
        eqUnit.bands[0].gain = gainAdjust
        eqUnit.bands[1].gain = gainAdjust
        eqUnit.bands[2].gain = gainAdjust
    }

    private func updateTimeStretch() {
        // Time stretch without pitch change
        pitchUnit.rate = timeStretch
    }

    private func updateVocalTractLength() {
        // Simulate vocal tract length changes using formant shifting
        updateFormantShift()
    }

    private func updateNoiseReduction() {
        // This would require a custom noise gate/reduction unit
        // For now, we can use EQ to reduce high-frequency noise
        if userEqUnit.bands.count >= 3 {
            userEqUnit.bands[2].gain = -noiseReduction * 10
        }
    }

    private func updateMasterVolume() {
        mixerNode.outputVolume = masterVolume
    }

    private func updateEQ() {
        guard userEqUnit.bands.count >= 3 else { return }
        
        userEqUnit.bands[0].gain = bassGain
        userEqUnit.bands[1].gain = midGain
        userEqUnit.bands[2].gain = trebleGain
    }

    private func updateReverb() {
        reverbUnit.wetDryMix = reverbAmount * 100
    }

    private func updateBitDepth() {
        // Bit depth crushing would require a custom audio unit
        // This is a placeholder for the effect
        distortionUnit.wetDryMix = (16.0 - bitDepth) / 16.0 * 100
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
            // Use the processing format for recording
            let format = processingFormat ?? mixerNode.outputFormat(forBus: 0)
            
            // Start the recorder
            recordingFile = try audioRecorder?.startRecording(format: format)
            isRecording = true
            
            print("Recording started with format: \(format)")
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        isRecording = false
        let url = audioRecorder?.stopRecording()
        
        print("Recording stopped: \(url?.lastPathComponent ?? "unknown")")
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
            
            // Attach effects nodes
            audioEngine.attach(pitchUnit)
            audioEngine.attach(userEqUnit)
            audioEngine.attach(eqUnit)
            audioEngine.attach(reverbUnit)
            audioEngine.attach(distortionUnit)
            audioEngine.attach(mixerNode)
            
            // CRITICAL FIX: Use consistent format throughout the chain
            // Create standard format matching the file's sample rate and channel count
            guard let standardFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: fileFormat.sampleRate,
                channels: fileFormat.channelCount,  // Match file's channel count
                interleaved: false
            ) else {
                print("Failed to create playback format")
                return
            }
            
            // Connect playback chain with consistent format
            // Player -> Effects -> Output (all using standardFormat)
            audioEngine.connect(player, to: pitchUnit, format: standardFormat)
            audioEngine.connect(pitchUnit, to: userEqUnit, format: standardFormat)
            audioEngine.connect(userEqUnit, to: eqUnit, format: standardFormat)
            audioEngine.connect(eqUnit, to: distortionUnit, format: standardFormat)
            audioEngine.connect(distortionUnit, to: reverbUnit, format: standardFormat)
            audioEngine.connect(reverbUnit, to: mixerNode, format: standardFormat)
            audioEngine.connect(mixerNode, to: outputNode, format: nil)  // Auto-convert to output
            
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
        let nodesToCleanup: [AVAudioNode] = [pitchUnit, userEqUnit, eqUnit, distortionUnit, reverbUnit, mixerNode]

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

