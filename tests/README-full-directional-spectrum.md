# Preserve supplied full-directional phases and force weights

Fixes https://github.com/amosborne/WEC-Sim/issues/12.

`spectrumImportFullDir` now uses a supplied finite real phase matrix with shape
[frequency,direction], preserving rows when filtering frequencies. Supplied phases
leave global RNG state unchanged; absent phases retain seeded/random behavior.
The native force function applies the same direction-bin widths as elevation,
including squared-amplitude mean drift. No new wave API, coefficient interface,
model port or library edit is introduced.

In a fresh MATLAB process with WEC-Sim dependencies, from this checkout:

```matlab
addpath('tests/helpers','tests/examples');
report = fullDirectionalSpectralExample(pwd,ABSOLUTE_NEW_OUTPUT_DIRECTORY,true);
assert(report.combined_pass);
results = runtests({'tests/fullDirectionalPhasesTest.m','tests/fullDirectionalWeightsTest.m'});
assertSuccess(results);
```

The same example runs before and after the corrections. It uses three nonuniform
frequencies, two directions, unequal amplitudes, explicit phases and distinct
complex six-mode transfer coefficients. Independent scalar elevation and force
sums use physical components. The actual native FullDir subsystem is checked
against both the native function and that physical sum. No oracle force history
is supplied to WEC-Sim and no body dynamics are simulated.

Ten controls cover phases, filtering, invalid phases, seeded fallback, RNG
isolation, uniform/nonuniform direction widths, nonzero mean drift and the native
signal subsystem. Force assertions use 1e-10 and elevation 1e-12. All coefficient
queries are nodes: this does not qualify interpolation, low-frequency
hydrodynamics, BEM resolution, coupled motion or other MATLAB/OS versions.
Sparse-direction and infinite-water visualization messages remain visible.
The narrowed source must be tested before acceptance.
