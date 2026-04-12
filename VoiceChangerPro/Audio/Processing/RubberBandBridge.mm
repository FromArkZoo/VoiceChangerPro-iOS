#import "RubberBandBridge.h"

#include "rubberband/RubberBandStretcher.h"
#include <cmath>
#include <cstring>
#include <vector>

using namespace RubberBand;

namespace {

// Simple mono scratch buffers held alongside the stretcher.
// Realtime Rubber Band can both consume more input than it emits and emit
// more output than we want in one shot — it maintains its own internal
// queues. Our caller expects strictly `frameCount` out for `frameCount` in
// (in-place), so we drain/zero-pad around each call.
struct RBPitchShifter {
    RubberBandStretcher *stretcher;
    double sampleRate;
};

} // namespace

struct RBPitchShifterOpaque {
    RBPitchShifter impl;
};

extern "C" {

RBPitchShifterRef rb_create(double sampleRate) {
    RBPitchShifterOpaque *handle = new RBPitchShifterOpaque();
    RubberBandStretcher::Options opts =
        RubberBandStretcher::OptionProcessRealTime    |
        RubberBandStretcher::OptionEngineFiner        |
        RubberBandStretcher::OptionFormantPreserved   |
        RubberBandStretcher::OptionPitchHighConsistency |
        RubberBandStretcher::OptionWindowStandard;

    handle->impl.stretcher = new RubberBandStretcher(
        static_cast<size_t>(sampleRate),
        /*channels*/ 1,
        opts,
        /*initialTimeRatio*/ 1.0,
        /*initialPitchScale*/ 1.0);
    handle->impl.sampleRate = sampleRate;
    return handle;
}

void rb_destroy(RBPitchShifterRef ref) {
    if (!ref) return;
    delete ref->impl.stretcher;
    delete ref;
}

void rb_reset(RBPitchShifterRef ref) {
    if (!ref || !ref->impl.stretcher) return;
    ref->impl.stretcher->reset();
}

void rb_set_pitch_semitones(RBPitchShifterRef ref, float semitones) {
    if (!ref || !ref->impl.stretcher) return;
    double scale = std::pow(2.0, static_cast<double>(semitones) / 12.0);
    ref->impl.stretcher->setPitchScale(scale);
}

void rb_process(RBPitchShifterRef ref, float *samples, int frameCount) {
    if (!ref || !ref->impl.stretcher || frameCount <= 0) return;
    RubberBandStretcher *s = ref->impl.stretcher;

    // Feed input (one mono channel pointer).
    const float *inPtr[1] = { samples };
    s->process(inPtr, static_cast<size_t>(frameCount), /*final*/ false);

    // Drain whatever's available up to frameCount. If the library hasn't
    // produced enough yet (startup delay) we zero-pad the tail.
    int avail = s->available();
    int want  = frameCount;
    int take  = avail > 0 ? std::min(avail, want) : 0;

    if (take > 0) {
        float *outPtr[1] = { samples };
        s->retrieve(outPtr, static_cast<size_t>(take));
    }
    if (take < want) {
        std::memset(samples + take, 0,
                    sizeof(float) * static_cast<size_t>(want - take));
    }
}

int rb_start_delay(RBPitchShifterRef ref) {
    if (!ref || !ref->impl.stretcher) return 0;
    return static_cast<int>(ref->impl.stretcher->getStartDelay());
}

} // extern "C"
