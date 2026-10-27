function tests = rigidHydroInertiaTest
% Same release input and native fixture for pre/post evidence.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
forkRoot = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
testCase.addTeardown(@() path(originalPath));
addpath(fullfile(forkRoot,'tests','helpers'));
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
output = fullfile(fixture.Folder,'native-measurements');
testCase.TestData.report = runRigidHydroInertiaProbe(forkRoot,output);
end

function testLibraryBoundaryIsCorrected(testCase)
% Intentionally fails on this draft until an audited library patch is present.
expected = ['body.hydroForce.([''hf'' num2str(body.variableHydro.' ...
    'hydroForceIndexInitial)]).adjustedInertiaProducts([3 2 1])'];
testCase.verifyEqual(testCase.TestData.report.source_expression,expected);
end

function testMinimalRollTorqueExample(testCase)
report = testCase.TestData.report;
before = report.modes{1}.single_roll_torque_measured_dry_acceleration;
after = report.modes{2}.single_roll_torque_measured_dry_acceleration;
expected = report.modes{2}.single_roll_torque_expected_dry_acceleration;
testCase.verifyGreaterThan(norm(before-expected,Inf),1e-5);
testCase.verifyEqual(after,expected,'AbsTol',1e-7);
end

function testNativeMatrixAndResidualComposition(testCase)
report = testCase.TestData.report;
testCase.verifyEqual(report.basis_indices,1:6);
for c = 1:2
    before = report.modes{1}.cases{c};
    after = report.modes{2}.cases{c};
    testCase.verifyGreaterThan(before.maximum_abs_error,1e-3);
    testCase.verifyEqual(after.reconstructed_full_matrix,after.expected_full_matrix,'AbsTol',1e-7);
    testCase.verifyEqual(after.public_products,[1.1 -1.3 1.7]);
    testCase.verifyEqual(before.public_products,after.public_products);
    testCase.verifyEqual(before.actual_residual,after.actual_residual);
end
adjusted = report.modes{2}.cases{2};
testCase.verifyGreaterThan(norm(adjusted.actual_residual-adjusted.actual_residual','fro'),1e-5);
end
