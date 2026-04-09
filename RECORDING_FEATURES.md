# Recording & Playback Features

## Overview
Added comprehensive recording and playback functionality to VoiceChangerPro, allowing users to record processed audio and play it back with effects.

## New Files Added

### 1. AudioRecorder.swift (`VoiceChangerPro/Audio/AudioRecorder.swift`)
**Purpose**: Handles real-time recording of processed audio

**Key Features**:
- Records to high-quality M4A format (AAC encoding)
- Real-time duration tracking
- Automatic timestamped filenames
- Saves to Documents directory
- Buffer-based writing for efficiency

**Public Methods**:
- `startRecording(format:)` - Begins recording with specified audio format
- `writeBuffer(_:)` - Writes audio buffer to file
- `stopRecording()` - Stops recording and returns file URL
- `cancelRecording()` - Cancels and deletes recording

### 2. RecordingManager.swift (`VoiceChangerPro/Models/RecordingManager.swift`)
**Purpose**: Manages the library of recorded audio files

**Key Features**:
- Automatic discovery of recordings in Documents directory
- Metadata extraction (duration, file size, date)
- File management (delete, share)
- Formatted display strings (duration, file size, date)

**Public Methods**:
- `loadRecordings()` - Scans Documents directory for audio files
- `addRecording(url:)` - Adds newly recorded file to list
- `deleteRecording(_:)` - Deletes recording from disk
- `shareRecording(_:)` - Returns URL for sharing

### 3. RecordingsListView.swift (`VoiceChangerPro/UI/RecordingsListView.swift`)
**Purpose**: Beautiful UI for browsing and managing recordings

**Key Features**:
- List view of all recordings with metadata
- Play/stop buttons for each recording
- Share functionality via iOS share sheet
- Swipe-to-delete support
- Empty state when no recordings exist
- Edit mode for bulk operations

**Components**:
- `RecordingsListView` - Main view
- `RecordingRow` - Individual recording item
- `ShareSheet` - iOS share sheet wrapper

### 4. Updated AudioEngine.swift
**New Features Added**:

**Recording Capabilities**:
- `@Published var isRecording: Bool` - Recording state
- `startRecording()` - Starts recording processed output
- `stopRecording()` - Stops and saves recording
- `cancelRecording()` - Cancels recording
- `getRecordingDuration()` - Returns current recording duration
- Automatic tap on mixer node to capture processed audio

**Playback Capabilities**:
- `@Published var isPlayingBack: Bool` - Playback state
- `@Published var playbackProgress: Double` - Playback progress (0-1)
- `startPlayback(url:)` - Plays recording with effects
- `stopPlayback()` - Stops playback
- Progress monitoring with timer
- Full effects chain applied to playback

### 5. Updated ContentView.swift
**New Features Added**:
- `@StateObject var recordingManager` - Recording manager instance
- Recordings button in navigation bar (folder icon)
- Recording controls appear when processing is active
- Live recording duration display
- Sheet presentation for RecordingsListView
- Pass recordingManager to MainControlsView

**MainControlsView Updates**:
- New recording button (appears during processing)
- Live duration counter while recording
- Visual feedback (green for ready, red while recording)
- Automatic save to RecordingManager on stop

## Usage Flow

### Recording Workflow:
1. **Start Processing**: Tap "Start" button
2. **Begin Recording**: Tap "Record" button (green)
3. **Monitor Duration**: Watch live counter (e.g., "0:15")
4. **Stop Recording**: Tap "Stop Recording" button (red)
5. **Auto-Save**: Recording automatically saved to Documents directory

### Playback Workflow:
1. **Open Recordings**: Tap folder icon in navigation bar
2. **Browse List**: See all recordings with metadata
3. **Play Recording**: Tap play button on any recording
4. **Apply Effects**: Adjust any effect parameters while playing
5. **Share**: Tap share button to export via AirDrop, Messages, etc.

## Technical Implementation

### Recording Pipeline:
```
Microphone Input → Effects Chain → Mixer Node → Tap → AudioRecorder → M4A File
```

### Playback Pipeline:
```
M4A File → AVAudioFile → Player Node → Effects Chain → Output
```

### File Storage:
- Location: `Documents/` directory
- Format: M4A (AAC encoding)
- Naming: `VoiceChanger_{timestamp}.m4a`
- Quality: High (AVAudioQuality.high)
- Sample Rate: Matches input (typically 48kHz)

### Effects During Playback:
All effects are applied to playback in real-time:
- Pitch shifting
- Formant shifting
- EQ (bass, mid, treble)
- Reverb
- Distortion (bit crushing)
- Master volume

This allows users to experiment with different effects on the same recording!

## User Interface

### Main Screen:
- **Recordings Button**: Top-left (folder icon)
- **Record Button**: Shows when processing is active
- **Duration Display**: Live counter while recording

### Recordings List:
- **Recording Name**: Filename with timestamp
- **Duration**: Formatted as M:SS
- **File Size**: Human-readable (e.g., "2.3 MB")
- **Date**: Formatted date/time
- **Play/Stop Button**: Large circular button
- **Share Button**: Export to other apps
- **Swipe to Delete**: Standard iOS pattern
- **Edit Mode**: Bulk operations

### States:
- **Empty State**: Helpful message when no recordings
- **Recording Active**: Red pulsing button with timer
- **Playback Active**: Blue play button, effects adjustable

## Benefits

1. **Creative Workflow**: Record once, experiment with effects multiple times
2. **High Quality**: Professional AAC encoding at 48kHz
3. **Easy Sharing**: Built-in iOS share sheet
4. **Persistent Storage**: Recordings saved between app launches
5. **Real-time Feedback**: Live duration counter while recording
6. **Flexible Playback**: Apply different effects to saved recordings

## Future Enhancements (Ideas)

- Trim/edit recordings
- Merge multiple recordings
- Add tags or categories
- Export with specific effect settings
- Waveform editing
- Loop playback mode
- Background recording
- Cloud sync (iCloud)

## Build Status
✅ Successfully built and integrated into VoiceChangerPro
✅ All files added to Xcode project
✅ Ready to run on simulator or device
