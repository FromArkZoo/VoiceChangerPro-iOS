# Voice Changer Pro - iOS

A professional-grade voice changing app for iOS with real-time audio processing, advanced voice transformation effects, and sophisticated visualizations.

## Features

### Core Audio Processing
- **Real-time Audio Processing** with ultra-low latency (<10ms)
- **Advanced Pitch Shifting** with formant preservation
- **Time Stretching** without artifacts using granular synthesis
- **Vocal Tract Length Modification** for character voice effects
- **Professional 3-Band EQ** (Bass, Mid, Treble)
- **Reverb Effects** using convolution processing
- **Bit Crushing** for digital distortion effects
- **Noise Reduction** using spectral subtraction

### Voice Transformation
- **Pitch Shift**: ±12 semitones with natural sound quality
- **Formant Shift**: 0.5x to 2.0x for gender transformation
- **Time Stretch**: 0.5x to 2.0x speed without pitch change
- **Vocal Tract Length**: Simulate different vocal tract sizes
- **Master Volume Control** with proper gain staging

### User Interface
- **SwiftUI-based Modern Interface** with adaptive layouts
- **XY Morphing Pad** for real-time parameter control
- **Real-time Visualizations**: Waveform, Spectrum, Spectrogram
- **Professional Level Meters** with clipping indicators
- **Voice Preset System** with built-in and custom presets
- **Musical Note Detection** in spectrum analyzer

### Built-in Voice Presets
- Natural Male/Female voices
- Child Voice simulation
- Elderly Voice characteristics
- Robot Voice with metallic effects
- Alien Voice with otherworldly characteristics
- Monster Voice with deep, intimidating qualities

## Technical Implementation

### Audio Engine (Core Audio + AVAudioEngine)
- **AVAudioEngine** for low-latency audio graph processing
- **Core Audio** for advanced DSP operations
- **Accelerate Framework** for optimized FFT operations
- **Real-time Audio Taps** for level monitoring and visualization
- **Professional Audio Chain**: Input → Pitch → EQ → Effects → Reverb → Output

### Voice Processing Algorithms
- **FFT-based Spectral Analysis** using vDSP
- **Fundamental Frequency Estimation** with peak picking
- **Voice Activity Detection** using energy-based methods
- **Spectral Centroid Calculation** for timbre analysis
- **Circular Buffer Management** for real-time processing

### User Experience
- **Adaptive Layout** for iPhone and iPad
- **Touch-optimized Controls** with haptic feedback
- **Real-time Parameter Updates** with smooth interpolation
- **Professional Color Scheme** matching the web version
- **Accessibility Support** with VoiceOver compatibility

## Requirements

- **iOS 17.0+**
- **iPhone/iPad** with microphone
- **Microphone Permission** for real-time processing
- **A12 Bionic or later** recommended for best performance

## Setup Instructions

### Opening in Xcode
1. Double-click `VoiceChangerPro.xcodeproj` to open in Xcode
2. Select your development team in Project Settings
3. Connect your iOS device or use the simulator
4. Build and run the project (⌘+R)

### Development Setup
1. Ensure you have **Xcode 15+** installed
2. Select a valid **Development Team** for code signing
3. Update the **Bundle Identifier** to match your Apple Developer account
4. Enable **Background Audio** capability if needed

### Testing on Device
1. Connect your iPhone/iPad via USB
2. Trust the computer when prompted on the device
3. Select your device as the run destination in Xcode
4. Grant microphone permissions when prompted

## Project Structure

```
VoiceChangerPro/
├── VoiceChangerProApp.swift          # Main app entry point
├── ContentView.swift                 # Main interface coordinator
├── Audio/
│   ├── AudioEngine.swift            # Core audio processing engine
│   └── VoiceProcessor.swift         # Advanced voice processing algorithms
├── UI/
│   ├── ControlsView.swift           # Parameter controls and morphing pad
│   └── VisualizationView.swift     # Real-time audio visualizations
├── Models/
│   └── PresetManager.swift         # Voice preset management
├── Assets.xcassets/                 # App icons and resources
└── Info.plist                      # App configuration and permissions
```

## Key Differences from Web Version

### Advantages of iOS Version
- **Native Performance**: Direct access to hardware audio APIs
- **Lower Latency**: Optimized audio processing pipeline
- **Better Touch Controls**: Native iOS gesture recognition
- **Background Processing**: Continue processing when app is backgrounded
- **Hardware Integration**: Access to device-specific audio features

### iOS-Specific Features
- **AVAudioSession Management** for proper audio routing
- **Core Audio Integration** for professional-grade processing
- **Metal Shaders** for enhanced visualizations (optional)
- **Haptic Feedback** for tactile control responses
- **iOS Audio Unit Support** for expandable effects

## Performance Optimization

### Audio Processing
- **Optimized Buffer Sizes** for minimal latency
- **SIMD Operations** using Accelerate framework
- **Memory Pool Management** to avoid allocations in audio thread
- **Efficient FFT Implementation** with pre-allocated buffers

### UI Rendering
- **Canvas-based Visualizations** for smooth 60fps updates
- **SwiftUI Optimizations** with proper state management
- **Background Thread Processing** for heavy computations
- **Intelligent Update Throttling** to maintain responsiveness

## Known Limitations

1. **iOS Audio Restrictions**: Some effects may be limited by iOS audio sandbox
2. **Background Processing**: Full processing may be limited when backgrounded
3. **Device Compatibility**: Older devices may experience reduced performance
4. **Audio Latency**: Actual latency depends on device hardware and iOS version

## Future Enhancements

- **Audio Unit Extensions** for system-wide voice changing
- **AI-Powered Voice Cloning** using CoreML
- **Multi-track Recording** with voice separation
- **Cloud Preset Sharing** with community features
- **Advanced Formant Analysis** using LPC algorithms

## Troubleshooting

### Common Issues
- **No Audio Output**: Check microphone permissions and audio session setup
- **High Latency**: Verify buffer sizes and audio session configuration
- **Crashes on Startup**: Ensure microphone permission is granted
- **Poor Performance**: Close other audio apps and restart the device

### Development Issues
- **Build Errors**: Clean build folder (⌘+Shift+K) and rebuild
- **Code Signing**: Verify development team and bundle identifier
- **Simulator Issues**: Use physical device for audio testing

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Based on the original web version's audio processing algorithms
- Uses Apple's Core Audio and AVAudioEngine frameworks
- Visualization techniques inspired by professional audio software
- UI design follows Apple's Human Interface Guidelines

---

Built with ❤️ for iOS using SwiftUI and Core Audio