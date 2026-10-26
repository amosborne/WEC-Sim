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

function testMeanDriftUsesSquaredPhysicalAmplitudesIndependentOfPhase(testCase)
fixture = fullDirectionalSpectralFixture(testCase.TestData.folder,[0;90],true);
hydro = fixture.hydro;
hydro.hydro_coeffs.excitation.re(:) = 0;
hydro.hydro_coeffs.excitation.im(:) = 0;
for frequency = 1:numel(fixture.omega)
    for direction = 1:numel(hydro.simulation_parameters.direction)
        theta = hydro.simulation_parameters.direction(direction);
        for mode = 1:6
            coefficient = .03*mode*(1+.1*fixture.omega(frequency))*(1+.2*cosd(theta));
            hydro.hydro_coeffs.mean_drift(mode,direction,frequency) = ...
                coefficient/(fixture.rho*fixture.g);
        end
    end
end
% Independent physical mean-drift sum: no spectrum/dOmega/dTheta reconstruction.
expected = zeros(1,6);
for mode = 1:6
    for direction = 1:numel(fixture.directions)
        for frequency = 1:numel(fixture.omega)
            coefficient = .03*mode*(1+.1*fixture.omega(frequency))* ...
                (1+.2*cosd(fixture.directions(direction)));
            expected(mode) = expected(mode)+fixture.amplitudes(frequency,direction)^2*coefficient;
        end
    end
end
first = mean_drift_wave(fixture,17);
probe = FullDirectionalSpectralProbe(hydro);
probe.prepare(first,fixture.rho,fixture.g);
firstForce = probe.evaluate(first,fixture.time);
testCase.verifyEqual(firstForce,repmat(expected,numel(fixture.time),1),'AbsTol',1e-10);
data = load(fixture.file);
data.phase = .31-data.phase;
save(fixture.file,'-struct','data');
second = mean_drift_wave(fixture,29);
testCase.verifyTrue(any(first.phase ~= second.phase,'all'));
probe = FullDirectionalSpectralProbe(hydro);
probe.prepare(second,fixture.rho,fixture.g);
secondForce = probe.evaluate(second,fixture.time);
testCase.verifyEqual(secondForce,repmat(expected,numel(fixture.time),1),'AbsTol',1e-10);
testCase.verifyEqual(secondForce,firstForce,'AbsTol',1e-10);
end

function testActualNativeBusMatchesPrescribedPhysicalComponents(testCase)
report = fullDirectionalSpectralExample(testCase.TestData.root, ...
    fullfile(testCase.TestData.folder,'native-bus'),true);
testCase.verifyLessThanOrEqual(report.bus_vs_native_function_max_abs_difference,1e-10);
testCase.verifyLessThanOrEqual(max(abs(report.native_bus_force ...
    -report.expected_force_actual_prepared_phase),[],'all'),1e-10);
testCase.verifyTrue(report.phase_pass);
testCase.verifyTrue(report.field_pass);
testCase.verifyTrue(report.weight_pass);
testCase.verifyLessThanOrEqual(report.bus_vs_physical_components_max_abs_difference,1e-10);
testCase.verifyTrue(report.combined_pass);
end

function verify_weights(testCase,directions)
report = fullDirectionalSpectralExample(testCase.TestData.root, ...
    tempname(testCase.TestData.folder),false,directions);
testCase.verifyLessThanOrEqual(report.amplitude_max_abs_difference,1e-12);
testCase.verifyTrue(report.weight_pass);
end

function waves = mean_drift_wave(fixture,seed)
waves = waveClass('spectrumImportFullDir');
waves.spectrumFile = fixture.file;
waves.phaseSeed = seed;
waves.setup(fixture.omega','infinite',0,fixture.dt,numel(fixture.time)-1, ...
    fixture.time',fixture.g,fixture.rho);
end
