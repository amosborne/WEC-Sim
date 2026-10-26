# Literal imported filepath regression

Own-fork issue: https://github.com/amosborne/WEC-Sim/issues/5.
Run in MATLAB from this repository root:

```matlab
results = runtests('tests/wavePathDisplayTest.m');
assertSuccess(results);
```

The test adds/restores this checkout's source path, warning settings and
`lastwarn`. It constructs wave objects and captures `listInfo` output; no
elevation file, wave setup, Topwater case, Simulink model, named shared engine,
Python or network is needed. Three drive/percent/UNC paths are tested as both
char and string values; another wave type must retain its exact display.

Freeze `source/objects/waveClass.m`, `source/objects/+internal/waveType.m`
and this test. For a stock comparison, use this same test file in a separate
clean `a23d2993807410fe78cc63546c1ba9d81912024f` checkout. Use a fresh MATLAB
process/class environment for each checkout so a previously loaded class
cannot hide the old behavior; the test does not clear other users' classes.
Stock output is expected to warn, truncate/format the char paths, or reject a
composed string format. Fixed output should print all six values verbatim
without warnings. This is a formatting check, not numerical validation.

Validated on Windows with MATLAB R2025b on 2026-10-25: all three corrected
tests passed. The release baseline failed the two path tests and passed the
unchanged-wave-type control. Stock and corrected runs used fresh MATLAB
processes; no Topwater case or body simulation was used.

Local Topwater evidence (not a file shipped in this fork):
`artifacts/workflow/fork-regressions-attempt3/{report.json,stock-results.json,fixed-results.json,terminal.json}`.
The tested production/test blobs are unchanged from candidate `e8491f4`;
subsequent validation documentation does not change those blobs.
Other OS/MATLAB versions remain untested. The Windows-looking strings do not
require a Windows filesystem; this test establishes formatting, not physics.
