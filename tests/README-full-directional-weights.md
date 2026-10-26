# Full directional force weights (own-fork issue13)

Issue: https://github.com/amosborne/WEC-Sim/issues/13

Base25b58bda96ab0272cbfb4b0755539d5bb8ca227e. This candidate is independent
of phase import. No history/convolution, inertia, low-frequency, interpolation
or library changes. Generic upstream correctness candidate; submitting upstream
needs explicit user permission. SOURCE ONLY: no execution or measured outcomes.

From this checkout in a fresh MATLAB process with WEC-Sim dependencies:

```matlab
addpath('tests/helpers','tests/examples');
report = fullDirectionalSpectralExample(pwd,ABSOLUTE_NEW_OUTPUT_DIRECTORY,true);
results = runtests('tests/fullDirectionalWeightsTest.m');
assert(all([results.Passed]));
```

The SAME example before/after uses3 nonuniform frequencies, column directions
0/90deg, unequal amplitudes, explicit phases and distinct complex six-mode/H
headings at exact coefficient nodes. WEC-Sim receives no force history. Independent
scalar oracles compute physical fields/forces. The actual native FullDir signal
subsystem is copied into a tiny model and its output recorded, without dynamics.

Expected distinction: baseline force omits direction widths present in elevation;
candidate matches the scalar sum within1e-10. Four controls cover0/90deg,0/60deg,
nonuniform[-60;0;90]deg widths and actual native-bus output. The weight oracle
uses ACTUAL prepared phases, isolating the correction even while phase import
remains unresolved on this topic. Actual values remain unmeasured.

The correction derives waveClass's exact existing bin widths from the native
function's `directions` argument and includes them once in C0/C1. No signature
or SLX change. Mean drift is zero in the fixture; no broader mean-drift or
physical accuracy qualification is claimed. Full packet low-frequency,
interpolation, startup/forces/motion, performance and broader MATLAB compatibility
remain separate. Only a separately reviewed combined candidate can claim both
phase and weight corrections.
