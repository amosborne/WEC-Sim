# Imported-excitation history and lag regression

Own-fork issue: https://github.com/amosborne/WEC-Sim/issues/1.
Candidate base: official v7.1.0, `a23d2993807410fe78cc63546c1ba9d81912024f`.
Future internal PR base: repository `amosborne/WEC-Sim`, branch
`topwater/reference`. No upstream issue/PR without specific user permission.

## Compatibility policy

The first imported wave still owns this preparation path. Directional
aggregation, dispatch, inertia, radiation and regular-wave calculations are
unchanged. Read its complete elevation file instead of using only the cropped
output samples. Compute

`F(t) = dt * sum_tau K(tau) * eta(t-tau)`

on the original `min(kt):dt:max(kt)` lag grid. No zero-lag anchoring, additional
kernel samples or fitted loads are introduced. This corrects array-centering
assumptions for asymmetric/one-sided/off-grid support.

Outside the COMPLETE input file, use the existing finite-record convention of
zero extension. Emit `WECsim:ImportedExcitationRecordSupport` once per preparation
call when any query needs missing history, with required and supplied time
ranges. This is an explicit endpoint assumption, not a calm-start or required-
padding gate. Nonfinite in-record samples remain errors, never replaced by zero.
Malformed/non-real tables, duplicate sample times, invalid ramp/time-step values
and nonfinite kernel/interpolation data also fail clearly.

The legacy seven-argument method signature (counting `obj`) remains valid:
`waveAmpTime` is already ramped and receives no second ramp. Two optional
arguments provide the raw complete record and ramp duration. Raw-history ramping
uses SOURCE time `s=t-tau` exactly once, matching `waveElevUser`:
unity for zero ramp; otherwise `(1+cos(pi+pi*s/R))/2`, with `s>=R` overridden to
one. There is NO new `s<=0` clamp. Negative-time cosine extension and absolute
ramp time with nonzero simulation start are retained for compatibility; this
does not recommend that extension as a physical startup model.

## Standalone regression

Run from this checkout in a fresh MATLAB class environment:

```matlab
results = runtests('tests/importedExcitationHistoryTest.m');
assertSuccess(results);
```

Tests create synthetic two-column files in owned temporary folders. Six
different channel kernels are compared against a scalar piecewise-linear
reference and nested source-time quadrature, without the production `interp1`
implementation. Coverage includes:

- Impulses before, inside and after the simulation interval, `dt=1` and `0.5`.
- Asymmetric, one-sided and off-grid lag supports on the original sample grid.
- Negative supplied history, zero/nonzero source-time ramp, nonzero output start.
- Legacy already-ramped input, partial files with one warning and zero extension.
- Malformed/nonfinite records and invalid kernels/time steps.
- An analytic six-channel regularCIC control through unchanged preprocessing.

Key history tests exercise production `hydroForcePre` and `waveClass.setup`.
The helper subclass only exposes protected excitation methods and stubs unrelated
mass/radiation preparation; it does not replace excitation or wave calculations.
No Topwater case/force table, BEM solve, Simulink model, named shared engine,
network or binary fixture is needed. The test restores source paths and warning
settings. It never globally clears classes or models.

Freeze this commit's `source/` tree, `tests/importedExcitationHistoryTest.m` and
`tests/helpers/ImportedExcitationHistoryProbe.m`, plus the MATLAB version used.
For a stock comparison, copy the SAME tests/helper into a separate clean
`a23d299` checkout. The full-file impulse and asymmetric tests should expose
crop/alignment defects; stock also lacks the new optional raw-history arguments
and named validation/warning behavior. The regular-wave control should pass.

Validated on Windows with MATLAB R2025b on 2026-10-25: all eleven corrected
tests passed. Stock failed ten and passed the regular-wave analytic control;
no tests were incomplete. The full-file history and asymmetric/one-sided lag
witnesses failed numerically through actual stock preprocessing, not merely
because stock lacks the optional arguments. Independent source review approved
the candidate; static checks of the new test/helper and execution wrapper were
clean. Stock and corrected runs used separate fresh hidden MATLAB processes.

Local Topwater evidence (not files shipped in this fork):
`artifacts/workflow/history-regressions-attempt1/{report.json,stock-results.json,fixed-results.json,terminal.json}`.
Exact processes were independently terminal/CIM and frozen-identity verified;
the serial lease was released. Production/test/helper blobs remain unchanged
from executed candidate `15a38c68b176cd121317a70d0571b0d4460370b1`; only this
validation documentation and commit message were amended.

This establishes excitation-only synthetic coverage. It does not qualify body
dynamics, multiple imports, the full upstream suite, the MATLAB/OS matrix,
large-table performance or physical motion accuracy. Earlier `2f43f54` evidence
used a different fatal-support/negative-time-clamp policy and remains historical.
No public outputs, runtime pin or other fork fixes change with this candidate.
