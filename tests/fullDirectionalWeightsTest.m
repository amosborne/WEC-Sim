function tests = fullDirectionalWeightsTest
tests = functiontests(localfunctions);
end

function setup(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
originalRandom = rng;
testCase.addTeardown(@() path(originalPath));
testCase.addTeardown(@() rng(originalRandom));
addpath(genpath(fullfile(root,'source')));
addpath(fullfile(root,'tests','helpers'));
addpath(fullfile(root,'tests','examples'));
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
testCase.TestData.folder = fixture.Folder;
testCase.TestData.root = root;
end

function testNinetyDegreeBinWeightsMatchPhysicalComponents(testCase)
verify_weights(testCase,[0;90]);
end

function testSixtyDegreeBinWeightsMatchPhysicalComponents(testCase)
verify_weights(testCase,[0;60]);
end

function testNonuniformDirectionWidthsMatchPhysicalComponents(testCase)
verify_weights(testCase,[-60;0;90]);
end

function testActualNativeBusUsesSameDirectionalWeights(testCase)
report = fullDirectionalSpectralExample(testCase.TestData.root, ...
    fullfile(testCase.TestData.folder,'native-bus'),true);
testCase.verifyLessThanOrEqual(report.bus_vs_native_function_max_abs_difference,1e-10);
testCase.verifyLessThanOrEqual(max(abs(report.native_bus_force ...
    -report.expected_force_actual_prepared_phase),[],'all'),1e-10);
% Supplied phase import is a separate issue; actual prepared phases isolate weight.
end

function verify_weights(testCase,directions)
report = fullDirectionalSpectralExample(testCase.TestData.root, ...
    tempname(testCase.TestData.folder),false,directions);
testCase.verifyLessThanOrEqual(report.amplitude_max_abs_difference,1e-12);
testCase.verifyTrue(report.weight_pass);
end
