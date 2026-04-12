#ifndef RubberBandBridge_h
#define RubberBandBridge_h

#include <stddef.h>

// Opaque C handle so Swift can import this header via the module map
// without needing a bridging header for the C++ side.
typedef struct RBPitchShifterOpaque *RBPitchShifterRef;

#ifdef __cplusplus
extern "C" {
#endif

RBPitchShifterRef rb_create(double sampleRate);
void              rb_destroy(RBPitchShifterRef ref);
void              rb_reset(RBPitchShifterRef ref);

// Pitch in semitones; bridge converts to scale = 2^(st/12).
void              rb_set_pitch_semitones(RBPitchShifterRef ref, float semitones);

// In-place mono pitch shift. `samples` is both input and output buffer.
// The library's realtime mode has an inherent startup delay; the bridge
// manages an internal fallback so the caller always gets `frameCount`
// samples out (zero-padded during warmup).
void              rb_process(RBPitchShifterRef ref, float *samples, int frameCount);

// Reported inherent delay in samples (for optional latency compensation).
int               rb_start_delay(RBPitchShifterRef ref);

#ifdef __cplusplus
}
#endif

#endif /* RubberBandBridge_h */
