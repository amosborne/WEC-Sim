# Correct Rigid Hydro inertia-product order

Fixes https://github.com/amosborne/WEC-Sim/issues/3.

The active Rigid Hydro File Solid (Simscape rigid-body block) expects products
`[Iyz Izx Ixy]`; WEC-Sim supplies public products as `[Ixy Ixz Iyz]`. The library
correction selects `adjustedInertiaProducts([3 2 1])` at
`Rigid Body/Hydrodynamic Body/Structure/Body Properties`. Public values/signs,
mass adjustment and balancing added-mass forces are unchanged.

## Minimal before/after example

From this checkout, in an isolated MATLAB process with Simulink, Simscape and
Multibody. Fixture construction uses physical-port APIs available in R2025a+.

```matlab
addpath('tests/examples');
report = rigidHydroInertiaExample;
```

Two short simulations copy the actual active Solid with the release and corrected
expression, using the same 7 kg body and rotational tensor
`[10 1.1 -1.3; 1.1 12 1.7; -1.3 1.7 14] kg*m^2`. From identity/rest/zero CG and
zero gravity, the same 1 N*m roll torque gives measured initial acceleration:

| rad/s^2 | Release expression | Corrected / independent M*a=w |
|---|---:|---:|
| Roll | 0.104094244641134 | 0.102615384041695 |
| Pitch | -0.015746134614160 | -0.010944563702830 |
| Yaw | 0.010903090436361 | 0.010857554110644 |

## Focused regression

```matlab
native = runtests('tests/rigidHydroInertiaTest.m');
assertSuccess(native);
samples = runtests('tests/probeInitialSampleTest.m');
assertSuccess(samples);
```

The three native tests use twelve simulations: six independent basis wrenches
identify each full 6x6 matrix for dry and adjusted bodies. Eight separate tests
check reading the logged sample-array shapes. These tests and the two-simulation
example passed on Windows/MATLAB R2025b at the corrected source. Matrix agreement
is asserted at 1e-7; the test explicitly demonstrates failure with the release
expression. The original nonsymmetric added-mass residual is added algebraically
to the measured adjusted component; dynamic residual-force application is not
claimed. The correction changes inertia ordering only, not damping.

The shipped archive preserves R2020b metadata and all unrelated model content;
strict comparison found exactly one changed property. Actual R2020b execution,
other platforms, Drag/Flex variants and the complete WEC-Sim suite remain untested.
These component tests do not establish hydrodynamic accuracy or full-body motion.
[Measured qualification and limits](https://github.com/amosborne/topwater/blob/8703b02/docs/experts/wecsim_expert/inertia-pr9-qualification-2026-10-26.md).
