function tests = fullDirectionalPhasesTest
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

function testSuppliedPhasesPreservePhysicalField(testCase)
report = fullDirectionalSpectralExample(testCase.TestData.root, ...
    fullfile(testCase.TestData.folder,'example'),false);
testCase.verifyTrue(report.phase_pass);
testCase.verifyLessThanOrEqual(report.amplitude_max_abs_difference,1e-12);
testCase.verifyTrue(report.field_pass);
end

function testFrequencyFilteringPreservesMatchingPhaseRows(testCase)
fixture = fullDirectionalSpectralFixture(testCase.TestData.folder,[0;90],true);
waves = fixture_wave(fixture);
waves.bem.range = [.9 1.7];
waves.setup(fixture.omega','infinite',0,fixture.dt,numel(fixture.time)-1,fixture.time',fixture.g,fixture.rho);
testCase.verifyEqual(waves.phase,fixture.phases(2:3,:));
end

function testInvalidPhaseMatrixFailsClearly(testCase)
fixture = fullDirectionalSpectralFixture(testCase.TestData.folder,[0;90],true);
data = load(fixture.file);
for invalid = {zeros(3,1),complex(ones(3,2),ones(3,2)), ...
        [NaN 0;0 0;0 0],[Inf 0;0 0;0 0]}
    data.phase = invalid{1};
    save(fixture.file,'-struct','data');
    waves = fixture_wave(fixture);
    testCase.verifyError(@() waves.setup(fixture.omega','infinite',0,fixture.dt,numel(fixture.time)-1, ...
        fixture.time',fixture.g,fixture.rho),'WECsim:InvalidFullDirectionalPhase');
end
end

function testMissingPhaseRetainsSeededRandomFallback(testCase)
fixture = fullDirectionalSpectralFixture(testCase.TestData.folder,[0;90],false);
first = fixture_wave(fixture);
second = fixture_wave(fixture);
first.setup(fixture.omega','infinite',0,fixture.dt,numel(fixture.time)-1,fixture.time',fixture.g,fixture.rho);
second.setup(fixture.omega','infinite',0,fixture.dt,numel(fixture.time)-1,fixture.time',fixture.g,fixture.rho);
testCase.verifySize(first.phase,[3 2]);
testCase.verifyEqual(first.phase,second.phase);
end

function testActualNativeBusKeepsPreparedPhaseBinding(testCase)
report = fullDirectionalSpectralExample(testCase.TestData.root, ...
    fullfile(testCase.TestData.folder,'native-bus'),true);
testCase.verifyTrue(report.phase_pass);
testCase.verifyLessThanOrEqual(report.bus_vs_native_function_max_abs_difference,1e-10);
% Direction weighting is independently tracked; do not claim its fix here.
end

function waves = fixture_wave(fixture)
waves = waveClass('spectrumImportFullDir');
waves.spectrumFile = fixture.file;
waves.phaseSeed = 17;
end
