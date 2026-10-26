# CAPYTAINE sidecar lifetime regression

Own-fork issue: https://github.com/amosborne/WEC-Sim/issues/4.
Run in MATLAB from this repository root:

```matlab
results = runtests('tests/readCapytaineHandlesTest.m');
assertSuccess(results);
```

The tests add/restore this checkout's source path and copy the checked-in
CAPYTAINE sphere/RM3 output files to owned temporary folders. No Python,
Capytaine solve, Topwater case, model, named shared engine or network is needed.
The suite includes an unrelated open-file sentinel; teardown closes only
new handles beneath its own temporary folder, including handles leaked by a
deliberately unpatched baseline. No global file/class/model clearing is used.

Freeze `source/functions/BEMIO/readCAPYTAINE.m`, `normalizeBEM.m`,
`addDefaultPlotVars.m`, this test, and all `.nc`/`.dat` files in
`examples/BEMIO/CAPYTAINE/{sphere,rm3}/outputs` for an allocated run.
For a stock comparison, use this same test file against a separate clean
`a23d2993807410fe78cc63546c1ba9d81912024f` checkout. Stock successful imports
are expected to leave KH probe handles and fail the inventory assertions;
the corrected importer should preserve the inventory and unrelated sentinel.
Repeated imports must match exactly; single-body added mass is checked directly
against the fixture's raw netCDF coefficients divided by density.

Validated on Windows with MATLAB R2025b on 2026-10-25: all six corrected tests
passed. The release baseline failed five tests and passed the malformed-
Hydrostatics control. The unrelated sentinel survived, and corrected fixture
rename/delete checks passed. Separate stock/corrected runs used fresh MATLAB
processes, without a Topwater case or body simulation.

An additional stock/corrected MAT comparison found exactly equal values in all
32 numeric fields for EACH sphere and RM3 fixture, using `assert_array_equal`.
This establishes numeric value equality, not byte identity or a dtype check.
Local Topwater evidence (not a file shipped in this fork):
`artifacts/workflow/fork-regressions-attempt3/{report.json,stock-results.json,fixed-results.json,terminal.json}`.
The tested production/test blobs are unchanged from candidate `54bca31`;
subsequent validation documentation does not change those blobs.

Coverage is selected single/multibody fixtures and malformed/missing sidecars,
not every OS, MATLAB release, netCDF layout or operating-system read fault.
R2025b uses `openedFiles`; the older-MATLAB `fopen('all')` fallback is untested.
