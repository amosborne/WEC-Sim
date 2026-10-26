# Rigid Hydro product ordering — issue #3

The active Rigid Hydro File Solid receives products in `[Ixy Ixz Iyz]` order,
while File Solid expects `[Iyz Izx Ixy]`. When the first and third products
differ, the native body has the wrong tensor and initial angular acceleration.
The intended library correction is exactly `adjustedInertiaProducts([3 2 1])`
at `Rigid Body/Hydrodynamic Body/Structure/Body Properties`.
Public properties, signs, mass adjustment and residual added mass stay unchanged.
Drag and Flex are outside this draft.

The corrected library is included. Strict archive comparisons found exactly one
changed expression and no other model content or metadata changes. A fresh
MATLAB load verified the exact property, original lock and R2020b metadata,
without changing file bytes. The portable packaging helper reproduced the same
candidate. Native tests on this proposed head remain pending; the PR remains a
draft and no production dependency pin has moved.

## Minimal same-input example

From this checkout, in an isolated MATLAB process with Simulink, Simscape and
Multibody (fixture construction uses R2025a+ physical-port APIs):

```matlab
addpath('tests/examples');
report = rigidHydroInertiaExample;
```

Two short simulations copy the actual active Solid, applying the release and
reordered expression to identical inputs. The 7 kg body has rotational tensor
`[10 1.1 -1.3; 1.1 12 1.7; -1.3 1.7 14] kg*m^2`. At identity/rest/zero CG and
zero gravity, the same 1 N*m roll torque gives these measured initial angular
accelerations on Windows/MATLAB R2025b:

| rad/s^2 | Release expression | Reordered / independent M*a=w |
|---|---:|---:|
| Roll | 0.104094244641134 | 0.102615384041695 |
| Pitch | -0.015746134614160 | -0.010944563702830 |
| Yaw | 0.010903090436361 | 0.010857554110644 |

The maximum acceleration error fell from 0.004801570911330492 to
1.3877787807814457e-17. These are **existing measured standalone results**, not
results from the newly packaged branch. The helper was ported from that source;
its only functional extension accepts either release or corrected source
expression so the same controlled witness can run before and after promotion.

## Full matrix regression and limits

```matlab
results = runtests({'tests/rigidHydroInertiaTest.m','tests/probeInitialSampleTest.m'});
assertSuccess(results);
```

Six independent unit forces/torques per mode identify each native 6x6 matrix
from directly measured t=0 acceleration columns. Twelve simulations cover both
expressions and two separate components: dry and production-adjusted. Production
`constAddedMassAndDamping` and `adjustMassMatrix` are used without modification;
the original nonsymmetric residual is then added **algebraically**.

Existing standalone matrix errors fell from 0.6000000000000012 to
5.329070518200751e-15 (dry), and from 0.5849999999999986 to
3.552713678800501e-15 (adjusted plus residual versus M+A). Eight layout controls
passed. Independent review accepted only this component-boundary evidence.
It does not prove actual H5/CIC loading, dynamic residual forces, current-boat
impact, full motion, damping accuracy, Drag/Flex or the OS/MATLAB matrix.
Added mass is water inertia; its numerical partition introduces no damping.

[Committed measured evidence and limits](https://github.com/amosborne/topwater/blob/9a922f1b7e1941c6b035c727794487cd2ca000f4/docs/experts/wecsim_expert/inertia-adjustment-proof-2026-10-25.md).
Raw private run directories referenced there are local evidence, not fork links.

## Reproduce the narrow library change

Start with the stock release library in a separate checkout. Use absolute paths,
fresh output directories and an isolated MATLAB process. Python 3 with SciPy is
needed to read the MATLAB preparation receipt; ZIP/XML handling uses the standard
library.

1. Add `tests/helpers` to the MATLAB path and run
   `prepareRigidHydroInertiaLibrary(stockLibrary,apiOutputDirectory)`. The supported
   API authors and reopens the new property, and preserves the original file.
   Direct R2020b export changed 53 unrelated entries in both control and candidate
   in our R2025b run, so those exports must not replace the shipped library.
2. Extract only the API-verified property onto the original archive:

   ```text
   python tests/helpers/extractRigidHydroInertiaDelta.py --stock ABS_STOCK_SLX --api-control ABS_API_OUTPUT/export-control/WECSim_Lib_Body_Elements.slx --api-candidate ABS_API_OUTPUT/export-candidate/WECSim_Lib_Body_Elements.slx --api-receipt ABS_API_OUTPUT/preparation.mat --api-source ABS_FORK/tests/helpers/prepareRigidHydroInertiaLibrary.m --output ABS_NEW_DELTA_OUTPUT
   ```

   This preserves the original XML encoding and every other uncompressed entry
   byte, entry order and non-derived archive metadata. Derived compressed sizes
   and offsets can change and are reported. Runtime hashes identify all supplied
   files; the preparation receipt records execution provenance, rather than
   authenticating historical file bytes.
3. Run `auditRigidHydroInertiaLibrary.py --stock ABS_STOCK_SLX --candidate
   ABS_GENERATED_SLX --mode control --report ABS_NEW_REPORT` for the generated
   control, then with `--mode candidate` for the candidate. Require zero versus
   exactly one intended change, no unexplained/added/removed entries, and original
   R2020b metadata. No serializer whitelist or Drag/Flex edit is permitted.
4. Load the candidate by absolute path in a fresh MATLAB process. Check its exact
   `FileName`, expected property, `Lock` on, `Dirty` off and
   `Simulink.MDLInfo(file).ReleaseName`. Close without saving and verify unchanged
   bytes. Then run the focused native tests above on the exact proposed revision.

The measured extraction passed both unchanged audits, and the portable helper
reproduced the identical candidate. Actual R2020b runtime compatibility remains
untested; the archive label alone does not establish it.
