# Directional imported excitation, applied once

Coupled aggregation and rigid dispatch correction for our fork's issue #2.
The working tree is based on combined `25b58bda96ab0272cbfb4b0755539d5bb8ca227e`,
then the **explicit history dependency** from PR #8 (`805bb29`) replayed as
`0335022`. Existing history source/tests remain unchanged by this group patch.
Validation results and the exact tested revision are recorded in the issue/PR.
This topic does not change Topwater's production dependency pin.
PR8 remains open/unmerged:805bb29 is the original dependency,0335022 its different
local replay identity. Any review must explicitly declare that dependency;
aggregation/dispatch is one separate logical fix. Preserve this checkout. After
PR8 is merged by the user, use a new isolated branch from the exact updated
topwater/reference and replay only the group patch before testing/promoting it.

`bodyClass.hydroForcePre` now computes each imported signal using that signal's
own direction and complete file, then sums on the shared simulation output grid.
Raw files may have different sample spacing. Nonfinite records and incomplete
support retain PR #8 semantics; no new ramp or forced calm prehistory is imposed.

The paired rigid mask change must call `importedExcitationBranches` so this total
is applied once. The helper validates clone ownership, internal parameters and
wiring before deleting recognized native clones and their positive sum ports.
Unrelated inputs are preserved; changed/custom clones fail without deletion.
Ordinary wave groups retain the original replication count.

The SLX changes one active rigid mask header. Strict archive audits and a fresh
absolute-path MATLAB load verified that header, original lock/R2020b metadata,
and unchanged file bytes after loading. Native applied-force tests are a separate
gate from archive validation. The earlier whole-library API save changed 188
unrelated entries and added two; none of that serialization was accepted.

To reproduce from a stock release library, add `tests/helpers` to the MATLAB
path and call `prepare_rigid_import_dispatch(stockLibrary,newApiDirectory)`.
Extract only its API-verified header onto the original archive:

```text
python tests/helpers/extractRigidImportedDispatchDelta.py --stock ABS_STOCK_SLX --api-candidate ABS_API_DIRECTORY/WECSim_Lib_Body_Elements.slx --api-receipt ABS_API_DIRECTORY/preparation.mat --api-source ABS_FORK/tests/helpers/prepare_rigid_import_dispatch.m --output ABS_NEW_DELTA_DIRECTORY
```

Python with SciPy is needed for receipt parsing. Runtime hashes identify the
supplied files; the receipt records execution provenance. The extractor preserves
XML entities and every other uncompressed entry and non-derived archive metadata.
Run `audit_rigid_dispatch_control.py --stock ABS_STOCK_SLX --control
ABS_GENERATED_CONTROL --report ABS_NEW_REPORT`, then
`audit_rigid_dispatch_archive.py --stock ABS_STOCK_SLX --candidate
ABS_GENERATED_CANDIDATE --report ABS_OTHER_NEW_REPORT`. Require zero/one intended
changes and zero unexplained, added or removed entries. Freshly load the generated
candidate, verify exact FileName/full script/lock/clean state/R2020b metadata,
close without saving, and confirm unchanged bytes before using it.

## Minimal pre/post example and regression

With the same files on stock and fixed sources:

```matlab
results = runtests('tests/importedExcitationGroupTest.m');
assertSuccess(results);
```

`testTwoDirectionalHistoriesSixChannels` is the minimal numerical witness. Two
unit elevation impulses at different times/directions drive distinct six-channel
kernels. The expected result is an independent scalar impulse/interpolation
sum. Stock/pre-history-only preprocessing uses only the first signal; the
candidate must produce both once. Different raw sample grids, reverse ordering,
single-component calls and repeat preparation are covered at two time steps.
For retained numerical before/after data, run the same example against the
PR #8-only baseline and paired candidate in separate fresh MATLAB processes:

```matlab
addpath('tests/examples');
report = importedExcitationGroupExample(forkRoot,newPrivateOutputDirectory);
```

It records actual prepared forces, the independent expected table and maximum
difference. Baseline mismatches remain visible rather than being reported as a pass.
The analytical dt1 oracle is F(t0)=[1 2 3 4 5 6],
F(t1)=[20 19 18 17 16 15], F(t2)=[-3 1 5 9 13 17],
F(t3)=[12 10 8 6 4 2], F(t4)=zeros(1,6). These are expected test values,
not newly measured native results.

`testNativeAppliedTotalExactlyOnce` simulates the actual library's imported
source and Add block using its original mask replication script. The unused
variant inputs are zero/terminated in this small signal fixture; no body
dynamics, generated Topwater force table, rebinding or external forces are used.
It also checks regular replication topology and return to one imported branch.
The regular transition is graph evidence only. The native imported source's
FromWorkspace expression remains unchanged. This fixture must run against the
reviewed prepared SLX to qualify the dispatch correction. Full production
applied-bus identity and the old-force baseline comparison remain separate gates.

Run all PR #8 history controls alongside this suite. Rigid imported excitation
is the intended scope. Drag/Flex, nonlinear hydro, Morison, variable hydrodynamics,
full dynamics accuracy, performance and the MATLAB/OS matrix are unqualified.
