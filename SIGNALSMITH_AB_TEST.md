# Signalsmith Stretch A/B test on device

The pitch-shift backend can now be flipped at compile time between Rubber Band
and Signalsmith Stretch via a single preprocessor define. Both bridge files
(`RubberBandBridge.mm` and `SignalsmithBridge.mm`) implement the same C
interface declared in `RubberBandBridge.h`, so `RubberBandPitchShifter.swift`
and the rest of the app are unchanged.

## Currently active: Signalsmith Stretch

Confirmed by `nm` on the build artifact: only `SignalsmithBridge.o` emits
the `_rb_*` symbols.

## How to flip back to Rubber Band (for A/B comparison)

In Xcode → VoiceChangerPro target → Build Settings → "Preprocessor Macros":

- Remove `VCP_USE_SIGNALSMITH=1` from both Debug and Release.

Or via `project.pbxproj` directly — delete the two `"VCP_USE_SIGNALSMITH=1",`
lines under `GCC_PREPROCESSOR_DEFINITIONS`.

Clean build (Cmd-Shift-K) then Run. Verify with:

```bash
nm $(find ~/Library/Developer/Xcode/DerivedData/VoiceChangerPro-* \
       -name "RubberBandBridge.o" | head -1) | grep "T _rb_"
```

Expect 6 symbols when RB is active, 0 when SS is active.

## What to listen for on device

Plug in headphones and try each preset / slider combo. Compare RB build to
SS build back-to-back on the same hardware, ideally same session.

| Test | RB expectation | SS expectation | Decision |
|---|---|---|---|
| **−12 semitones (deep "demon")** | Smooth low growl, formants intact | Should sound similar — formant preservation is on | If SS sounds like a robot or chipmunk-in-reverse, that's a regression |
| **+12 semitones ("chipmunk")** | Tight, formant-corrected high voice | Similar; some "shimmer" artifacts acceptable | If SS sounds garbled or transient-smeared, regression |
| **±3 semitones (natural mid-range)** | Most-used range; should sound natural | Should sound natural; minor spectral differences OK | This is the make-or-break test for everyday use |
| **Whispers / breathy speech** | Some artifacts inevitable | Some artifacts inevitable | Compare relative quality |
| **Sibilance ("ssss" sounds)** | Slight smearing | Slight smearing | Major degradation = regression |
| **CPU / latency feel** | Audible startup delay (`getStartDelay`) | Slightly different latency profile | Should not feel laggier |

## Decision

- ✅ **SS holds up**: continue to task #7 (cut over: delete RB, ~820K + 60 files)
- ⚠️ **SS regresses on ≤3 semitones**: try tuning `setFormantBase` (currently
  200 Hz hint) — adjust to your typical input pitch
- 🚫 **SS regresses badly across the board**: revert (just remove the define)
  and re-evaluate. AVAudioUnitTimePitch is the next free option to try.

## What was changed (so revert is easy)

```
Added:    VoiceChangerPro/Audio/Processing/SignalsmithBridge.mm
Added:    VoiceChangerPro/ThirdParty/signalsmith-stretch/   (1.4 MB)
Added:    VoiceChangerPro/ThirdParty/signalsmith-linear/    (header dep, tag 0.3.1)
Modified: VoiceChangerPro/Audio/Processing/RubberBandBridge.mm   (added #ifndef guard)
Modified: VoiceChangerPro.xcodeproj/project.pbxproj
            - Added file ref + build file + group entry + sources entry
            - Added VCP_USE_SIGNALSMITH=1 to both Debug and Release
            - Added 2 header search paths to both Debug and Release
```

To fully revert: `git checkout .` and `rm -rf VoiceChangerPro/ThirdParty/signalsmith-*`.
