# Preserve full directional spectral inputs (own-fork issue12)

Issue: https://github.com/amosborne/WEC-Sim/issues/12

This single correction preserves supplied phases and applies the same direction
weights in elevation and excitation. It is based on combined25b58b. No imported-
elevation/history/convolution, inertia, coefficient interpolation, low-frequency
handoff or library changes are included. It is a generic upstream correctness
candidate; submitting upstream requires explicit user permission.

In a fresh MATLAB process from this checkout, with WEC-Sim dependencies:

```matlab
addpath('tests/helpers','tests/examples');
report = fullDirectionalSpectralExample(pwd,ABSOLUTE_NEW_OUTPUT_DIRECTORY,true);
assert(report.combined_pass);
results = runtests({'tests/fullDirectionalPhasesTest.m','tests/fullDirectionalWeightsTest.m'});
assert(all([results.Passed]));
```

The SAME example runs before/after with one FullDir object,3 nonuniform
frequencies [.4,.9,1.7]rad/s, column directions0/90deg, unequal amplitudes,
explicit phases and distinct complex six-mode/per-heading H. Every H query is
at a coefficient node; this excludes interpolation from the witness. An
independent scalar oracle forms physical elevation and forces. WEC-Sim receives
wave inputs and coefficient tables, never an oracle force history. The actual
native FullDir signal subsystem is copied into a tiny model and its output
checked against both the native function and the prescribed physical sum.
There is no body simulation or IRF.

Optional MAT field `phase` must be finite real [nFrequencies,nDirections]. Missing
field retains the native seeded/random behavior and existing RNG setup. Direction
weights reproduce waveClass's exact bin rule from the function's existing
direction vector; no new argument, port, model save or SLX edit is needed.

There are9 focused controls:4 phase controls (supplied physical field, filtering,
invalid phases and seeded fallback),3 first-order width controls (0/90deg,
0/60deg and nonuniform[-60;0;90]deg),1 mean-drift-only control and1 combined
actual native-bus control. The mean-drift witness zeros oscillatory H, compares
the native function against an independent sum of a^2 times dimensional mean-
drift coefficients and changes phases to verify invariance. Physical force
assertions use1e-10 and fields1e-12, without changing original tolerances.

Measured first step on Windows/R2025b, before combining: baseline phase error
6.2628106249rad, field error0.7862334196m, weight-only six-channel difference
0.4107283522; phase-only head150a66d had exact supplied phases and field error
1.11e-16m; weight-only headf72c5cc reduced weight-only difference to1.11e-15.
All7 allocated non-bus controls passed. The actual before/after arrays are
retained by Topwater's native-spectral-small-attempt1 evidence. Those are
synthetic component results, not physical accuracy or combined-head acceptance.

Combined validation passed on Windows/R2025b at exact scientific-source head
8ee8dcb199f21a08cf81e61bfab141d0b0624364: all9 controls and the portable actual-
block example passed in172.475s. Supplied phase error was0; maximum field error
1.11e-16m; native-function/physical-force difference1.33e-15; actual bus matched
the native function exactly and the physical sum within1.33e-15. The mean-drift
control passed its1e-10 assertions; no separate raw MD roundoff maximum is claimed.
Local retained Topwater evidence: `native-spectral-combined-attempt1/check/`
contains acceptance, report, raw arrays, test results and transcript. These local
artifacts are not shipped in this fork. Later documentation changes do not alter
that exact tested scientific source.

The transcript retains the generic coarse-direction coverage warning: the
synthetic headings are deliberately sparse, and every test query is at an
explicit coefficient node. This does not qualify off-grid interpolation or
physical BEM resolution. The native "200m for visualization" message accompanies
infinite-water setup; the deep-water flag remains enabled and no finite-depth
hydrodynamics is introduced. Warnings were not suppressed or treated as proof of
broader accuracy.

Full packet low-frequency/seam/interpolation handoff, actual force/startup/motion
comparison, performance and broader MATLAB compatibility remain separate. No
runtime pin or upstream promotion.
