# Rigid Hydro product ordering — draft for issue #3

The active Rigid Hydro File Solid receives products in `[Ixy Ixz Iyz]` order,
while File Solid expects `[Iyz Izx Ixy]`. When the first and third products
differ, the native body has the wrong tensor and initial angular acceleration.
The intended library correction is exactly `adjustedInertiaProducts([3 2 1])`
at `Rigid Body/Hydrodynamic Body/Structure/Body Properties`.
Public properties, signs, mass adjustment and residual added mass stay unchanged.
Drag and Flex are outside this draft.

**Draft status: no corrected library binary is included.** The release SLX is
unchanged. The supported-API export recipe and the packaged test layout have not
run in this branch. `testLibraryBoundaryIsCorrected` deliberately fails until an
independently audited narrow SLX correction is present. This must not be merged
as a complete fix or used to move a production pin.

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

## Remaining narrow binary gate

`tests/helpers/prepareRigidHydroInertiaLibrary.m` proposes direct supported-API
R2020b exports of an untouched control and one-property candidate into separate
private copies. It makes no intermediate R2025b save or original overwrite.
`auditRigidHydroInertiaLibrary.py` must accept the original/control comparison
with zero changes, and original/candidate with exactly the active rigid product
expression change. Every other archive semantic must remain unchanged, including
release metadata. No serializer whitelist or Drag/Flex edit is permitted.

Only after both audits, reopen and rerun the focused native regressions, then
independently review and promote that exact binary. Existing unrelated
serialization failures are preserved; this recipe has not established that
R2025b can produce the required narrow export. A no-op export alone would not
prove physical equivalence. Actual R2020b runtime compatibility is untested.
