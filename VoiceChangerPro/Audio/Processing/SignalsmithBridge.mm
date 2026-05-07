#import "RubberBandBridge.h"

// Compiled only when VCP_USE_SIGNALSMITH is defined. The RubberBandBridge.mm
// counterpart is compiled only when it is NOT defined. Both files implement
// the same extern "C" symbols, so exactly one must end up in the link.
#ifdef VCP_USE_SIGNALSMITH

#import <Foundation/Foundation.h>

// Signalsmith Stretch — header-only, MIT.
// Depends on signalsmith-linear/stft.h, supplied via header search path
// pointing at ThirdParty/signalsmith-linear/include/.
#include "signalsmith-stretch.h"

#include <cmath>
#include <cstring>
#include <vector>
#include <algorithm>

// Drop-in replacement for RubberBandBridge.mm. Implements the same opaque
// C interface declared in RubberBandBridge.h, so RubberBandPitchShifter.swift
// is unchanged. Selected at compile time when VCP_USE_SIGNALSMITH is defined
// (see VoiceChangerPro target build settings).
//
// Differences from the RB implementation that matter to the caller:
//   - Signalsmith Stretch process() is NOT in-place. Input and output buffers
//     must differ. We hold an internal scratch vector to copy the in-place
//     caller buffer into, then write output back over the caller buffer.
//   - There is no "available()" queue — for pitch-only (no time stretch), we
//     pass inLen == outLen and get exactly that many output samples.
//   - Formant preservation is enabled via setFormantFactor(1.0, compensate=true)
//     with a 200 Hz fundamental hint, mirroring RB's OptionFormantPreserved.

namespace {

using StretchT = signalsmith::stretch::SignalsmithStretch<float>;

struct SSPitchShifter {
    StretchT stretch;
    double sampleRate = 0.0;
    std::vector<float> scratch;   // input copy; SS forbids in-place
    int processCallCount = 0;     // throttle log spam from audio thread
};

} // namespace

struct RBPitchShifterOpaque {
    SSPitchShifter impl;
};

extern "C" {

RBPitchShifterRef rb_create(double sampleRate) {
    auto *handle = new RBPitchShifterOpaque();
    handle->impl.sampleRate = sampleRate;

    handle->impl.stretch.presetDefault(/*channels*/ 1,
                                       static_cast<float>(sampleRate),
                                       /*splitComputation*/ true);

    handle->impl.stretch.setFormantFactor(1.0f, /*compensatePitch*/ true);
    handle->impl.stretch.setFormantBase(200.0f / static_cast<float>(sampleRate));

    handle->impl.scratch.reserve(4096);

    NSLog(@"VCP-SS-CREATE sr=%.1f inputLatency=%d outputLatency=%d blockSamples=%d intervalSamples=%d",
          sampleRate,
          handle->impl.stretch.inputLatency(),
          handle->impl.stretch.outputLatency(),
          handle->impl.stretch.blockSamples(),
          handle->impl.stretch.intervalSamples());

    return handle;
}

void rb_destroy(RBPitchShifterRef ref) {
    if (!ref) return;
    delete ref;
}

void rb_reset(RBPitchShifterRef ref) {
    if (!ref) return;
    ref->impl.stretch.reset();
}

void rb_set_pitch_semitones(RBPitchShifterRef ref, float semitones) {
    if (!ref) return;
    NSLog(@"VCP-SS-SETPITCH semitones=%.2f", semitones);
    ref->impl.stretch.setTransposeSemitones(semitones);
}

static float rms_of(const float *p, int n) {
    double s = 0.0;
    for (int i = 0; i < n; ++i) s += double(p[i]) * double(p[i]);
    return float(std::sqrt(s / std::max(1, n)));
}

void rb_process(RBPitchShifterRef ref, float *samples, int frameCount) {
    if (!ref || !samples || frameCount <= 0) return;
    auto &impl = ref->impl;

    if (static_cast<int>(impl.scratch.size()) < frameCount) {
        impl.scratch.resize(static_cast<size_t>(frameCount));
    }

    std::memcpy(impl.scratch.data(), samples,
                sizeof(float) * static_cast<size_t>(frameCount));

    float inRMS = rms_of(impl.scratch.data(), frameCount);

    float *inPtr  = impl.scratch.data();
    float *outPtr = samples;
    float **inputs  = &inPtr;
    float **outputs = &outPtr;

    impl.stretch.process(inputs, frameCount, outputs, frameCount);

    float outRMS = rms_of(samples, frameCount);

    // Throttle log: every 50 calls (~1/sec at 256 frames @ 48kHz)
    // Log on first call, on energy spikes, and periodically.
    int n = ++impl.processCallCount;
    if (n <= 5 || n % 50 == 0) {
        NSLog(@"VCP-SS-PROCESS #%d frames=%d inRMS=%.5f outRMS=%.5f in[0..2]=%.4f,%.4f,%.4f out[0..2]=%.4f,%.4f,%.4f",
              n, frameCount, inRMS, outRMS,
              impl.scratch[0], impl.scratch[std::min(1, frameCount-1)], impl.scratch[std::min(2, frameCount-1)],
              samples[0],      samples[std::min(1, frameCount-1)],      samples[std::min(2, frameCount-1)]);
    }
}

int rb_start_delay(RBPitchShifterRef ref) {
    if (!ref) return 0;
    // Closest analog to RB's getStartDelay() — samples of output latency
    // before "real" pitch-shifted output appears post-reset.
    return ref->impl.stretch.outputLatency();
}

} // extern "C"

#endif // VCP_USE_SIGNALSMITH
