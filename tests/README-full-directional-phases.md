# Full directional phase import (own-fork issue12)

Issue: https://github.com/amosborne/WEC-Sim/issues/12

Base25b58bda96ab0272cbfb4b0755539d5bb8ca227e. This candidate is independent
of the weight correction. No history/convolution, inertia, low-frequency,
interpolation or library changes. Generic upstream correctness candidate;
submitting upstream needs explicit user permission. SOURCE ONLY: no test
execution or measured outcomes yet.

From this checkout in a fresh MATLAB process with WEC-Sim dependencies:

```matlab
addpath('tests/helpers','tests/examples');
report = fullDirectionalSpectralExample(pwd,ABSOLUTE_NEW_OUTPUT_DIRECTORY,true);
results = runtests('tests/fullDirectionalPhasesTest.m');
assert(all([results.Passed]));
```

The SAME example before/after uses3 nonuniform frequencies, column directions
0/90deg, unequal amplitudes, explicit phases and distinct complex six-mode/H
headings at exact coefficient nodes. WEC-Sim receives no force history. Independent
scalar oracles compute physical fields/forces. The actual native FullDir signal
subsystem is copied into a tiny model and its output recorded, without dynamics.

Expected baseline/candidate distinction: stock ignores the supplied3x2 phase
matrix; candidate preserves it exactly and matches physical origin/off-origin
elevation within1e-12. Five controls cover filtering, invalid data, seeded
fallback and actual native-bus/function binding within1e-10. Actual values remain
unmeasured. The separate weight diagnostic is intentionally expected to fail
on this phase-only topic.

The optional MAT field is `phase`, finite real [nFrequencies,nDirections]. Missing
field retains existing seeded/random behavior and RNG setup. Full packet,
low-frequency bridge, interpolation, startup/forces/motion, performance and broader
MATLAB compatibility remain separate. Only a separately reviewed combined
candidate can claim both phase and weight corrections.
