# Crash Diagnosis & Resolution Guide

## 🔍 What I Fixed

I've added extensive logging and safety checks to identify the crash. The code will now print detailed information when you press "Start".

## 📋 Pre-Flight Checklist

### 1. **Check Info.plist for Microphone Permission**

Your app MUST have this key in `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Voice Changer needs microphone access to process your voice in real-time.</string>
```

**Without this, your app will crash immediately when accessing the microphone!**

### 2. **Check Console Output**

When you run the app and press "Start", look for these messages in the Xcode console:

#### ✅ **Success Pattern:**
```
🔄 Starting audio processing...
🔄 Setting up audio graph...
   Input format: <AVAudioFormat ...>
   Sample rate: 44100.0, Channels: 1
   Processing format: <AVAudioFormat ...>
🔄 Attaching audio nodes...
   ✓ All nodes attached
🔄 Connecting audio chain...
   ✓ Input -> Pitch
   ✓ Pitch -> UserEQ
   ...
✅ Audio processing started successfully
```

#### ❌ **Crash/Error Patterns:**

**Pattern A: Permission Issue**
```
❌ Microphone permission denied
```
**Fix:** Enable microphone permission in Settings > Privacy & Security > Microphone

**Pattern B: Format Issue**
```
❌ Failed to create standard format
❌ Invalid input format detected
```
**Fix:** Audio hardware not responding, try restarting device

**Pattern C: Audio Session Issue**
```
⚠️ '!pri' - Audio session privacy/permission issue
Error code: 561145187
```
**Fix:** Missing Info.plist entry for NSMicrophoneUsageDescription

**Pattern D: Connection Error**
```
❌ Error connecting nodes: ...
Error code: -10863
```
**Fix:** Format mismatch between nodes

---

## 🛠️ Quick Fixes

### Fix 1: Add Info.plist Entry

If you don't have an `Info.plist` file:

1. In Xcode, select your project in the navigator
2. Select your app target
3. Go to the "Info" tab
4. Click the "+" button under "Custom iOS Target Properties"
5. Add: `Privacy - Microphone Usage Description`
6. Value: `Voice Changer needs microphone access to process your voice in real-time.`

### Fix 2: Check Audio Session

The code now checks for:
- ✅ Microphone permissions
- ✅ Valid input format
- ✅ Proper node connections
- ✅ Audio session activation

### Fix 3: Reset Simulator/Device

Sometimes the audio system gets stuck:

**Simulator:**
1. Device > Erase All Content and Settings
2. Rebuild and run

**Physical Device:**
1. Settings > Privacy & Security > Microphone
2. Toggle your app off and on
3. Restart the app

---

## 🔬 Debugging Steps

### Step 1: Look at Console Output
Run the app and press "Start". Copy ALL the console output and look for:
- Error codes (numbers like -10863, 561145187)
- Red ❌ messages
- Where it stopped (last ✓ message before crash)

### Step 2: Check Crash Log
If the app crashes completely:
1. In Xcode, go to Window > Devices and Simulators
2. Select your device
3. Click "View Device Logs"
4. Find the most recent crash for your app
5. Look at the "Exception Type" and "Crashed Thread"

### Step 3: Common Crash Signatures

| Crash Type | Likely Cause | Fix |
|------------|--------------|-----|
| `EXC_BAD_ACCESS` in `AVAudioEngine` | Format mismatch | Already fixed in code |
| `NSInternalInconsistencyException` | Node connection issue | Check console for connection errors |
| `Assertion failed` with `isInputConnToConverter` | Format conversion error | Already fixed in code |
| Immediate crash with no logs | Missing permission key | Add NSMicrophoneUsageDescription |
| `AVAudioSessionErrorCodeInsufficientPriority` | Audio session conflict | Close other audio apps |

---

## 🎯 Most Likely Issues

Based on your description ("ran and then crashed when I pressed Start"):

### 1. **Missing NSMicrophoneUsageDescription (90% likely)**
**Symptom:** Immediate crash, no error message, just quits
**Fix:** Add the Info.plist key shown above

### 2. **Microphone Permission Denied (5% likely)**
**Symptom:** Crash with permission-related error
**Fix:** Enable in Settings

### 3. **Audio Format Issue (4% likely)**
**Symptom:** Crash after "Starting audio engine..." message
**Fix:** Already implemented in the code

### 4. **Node Connection Error (1% likely)**
**Symptom:** Crash during "Connecting audio chain..."
**Fix:** Check console output for specific connection that failed

---

## 📱 What To Do Now

### Option A: Run and Share Console Output
1. Run the app
2. Press "Start"
3. Copy everything from the console
4. Share it with me

I'll tell you exactly what the issue is.

### Option B: Check Info.plist First
1. Open `Info.plist` in your project
2. Look for `NSMicrophoneUsageDescription`
3. If it's not there, add it
4. Clean build (Cmd+Shift+K)
5. Run again

### Option C: Quick Test
Try this minimal test:
```swift
// Add this button to your UI temporarily
Button("Test Microphone Permission") {
    AVAudioApplication.shared.requestRecordPermission { granted in
        print("Microphone permission: \(granted)")
    }
}
```

If this doesn't show a permission dialog, you're missing the Info.plist key.

---

## 🚨 Emergency Fallback

If nothing works, try this simplified version in `startProcessing()`:

```swift
// Temporary simplified start (for debugging only)
func startProcessing() throws {
    print("🔄 Simplified start test...")
    
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker])
    try audioSession.setActive(true)
    
    print("✓ Audio session active")
    
    audioEngine.prepare()
    try audioEngine.start()
    
    print("✓ Engine started")
    isProcessing = true
}
```

If this works, the issue is in the graph setup.
If this still crashes, it's a permission or audio session issue.

---

## 📞 Next Steps

Run the app and tell me:
1. **Where in the console output does it stop?** (last message you see)
2. **What error code do you see?** (if any)
3. **Do you have NSMicrophoneUsageDescription in Info.plist?**

I'll provide the exact fix!
