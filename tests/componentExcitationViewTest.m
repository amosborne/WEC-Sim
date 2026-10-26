function tests = componentExcitationViewTest
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
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
testCase.TestData.folder = fixture.Folder;
end

function testDerivedNodesDriveNativeForceWithoutChangingRawHydro(testCase)
[fixture,hydro,waves] = component_fixture(testCase.TestData.folder);
probe = FullDirectionalSpectralProbe(hydro);
before = probe.hydroData;
probe.prepare(waves,fixture.rho,fixture.g);
testCase.verifyEqual(probe.hydroData,before);
testCase.verifyLessThan(min(waves.omega),min(hydro.simulation_parameters.w));
actual = probe.evaluate(waves,fixture.time);
view = hydro.hydro_coeffs.excitation.component_view;
[~,iw] = ismember(waves.omega,view.omega_rad_s);
[~,it] = ismember(waves.fullDirectionalSpectrum.directions,view.headings_deg);
expected = zeros(numel(fixture.time),6);
for sample = 1:numel(fixture.time)
    for mode = 1:6
        for direction = 1:2
            for frequency = 1:3
                h = fixture.rho*fixture.g*complex(view.re(mode,it(direction),iw(frequency)), ...
                    -view.im(mode,it(direction),iw(frequency)));
                angle = waves.omega(frequency)*fixture.time(sample)+fixture.phases(frequency,direction);
                expected(sample,mode) = expected(sample,mode)+fixture.amplitudes(frequency,direction)* ...
                    (real(h)*cos(angle)+imag(h)*sin(angle));
            end
        end
    end
end
testCase.verifyEqual(actual,expected,'AbsTol',1e-10);
end

function testViewRejectsUnsupportedModeAndMeanDrift(testCase)
[~,hydro,~] = component_fixture(testCase.TestData.folder);
testCase.verifyError(@() getExcitationData(hydro,'elevationImport'),'WECsim:UnsupportedExcitationView');
invalid = hydro;
invalid.hydro_coeffs.excitation.component_view.md(1,2,2) = 1;
testCase.verifyError(@() getExcitationData(invalid,'spectrumImportFullDir'),'WECsim:UnsupportedExcitationView');
invalid = hydro;
invalid.hydro_coeffs.mean_drift(1,1,1) = 1;
testCase.verifyError(@() getExcitationData(invalid,'spectrumImportFullDir'),'WECsim:UnsupportedExcitationView');
end

function testViewRequiresFiniteClosedAxesAndExactQueryNodes(testCase)
[fixture,hydro,waves] = component_fixture(testCase.TestData.folder);
invalid = hydro;
invalid.hydro_coeffs.excitation.component_view.im(1,1,2) = NaN;
testCase.verifyError(@() getExcitationData(invalid,'spectrumImportFullDir'),'WECsim:InvalidExcitationView');
invalid = hydro;
invalid.hydro_coeffs.excitation.component_view.re(1,end,2) = ...
    invalid.hydro_coeffs.excitation.component_view.re(1,end,2)+1;
testCase.verifyError(@() getExcitationData(invalid,'spectrumImportFullDir'),'WECsim:InvalidExcitationView');
invalid = hydro;
invalid.hydro_coeffs.excitation.component_view.omega_rad_s(2) = .031;
probe = FullDirectionalSpectralProbe(invalid);
testCase.verifyError(@() probe.prepare(waves,fixture.rho,fixture.g),'WECsim:InvalidExcitationView');
end

function testLegacyAxisSelectionRemainsRaw(testCase)
[~,hydro,~] = component_fixture(testCase.TestData.folder);
hydro.hydro_coeffs.excitation = rmfield(hydro.hydro_coeffs.excitation,'component_view');
selected = getExcitationData(hydro,'spectrumImportFullDir');
testCase.verifyFalse(selected.uses_component_view);
testCase.verifyEqual(selected.w,hydro.simulation_parameters.w);
testCase.verifyEqual(selected.direction,hydro.simulation_parameters.direction);
testCase.verifyEqual(selected.re,hydro.hydro_coeffs.excitation.re);
testCase.verifyEqual(selected.im,hydro.hydro_coeffs.excitation.im);
end

function [fixture,hydro,waves] = component_fixture(folder)
fixture = fullDirectionalSpectralFixture(folder,[0;90],true);
data = load(fixture.file);
data.frequencies = [.03;.7;1.2]/(2*pi);
data.directions = [-170;13];
nativeOmega = (data.frequencies.*2).*pi;
dw = [nativeOmega(2)-nativeOmega(1); ...
    (nativeOmega(3)-nativeOmega(1))/2;nativeOmega(3)-nativeOmega(2)];
dtheta = deg2rad(diff(data.directions));
energy = sum(fixture.amplitudes.^2,2);
data.spectrum = pi*energy./dw;
data.spread = fixture.amplitudes.^2./(energy*[dtheta dtheta]);
save(fixture.file,'-struct','data');
hydro = fixture.hydro;
hydro.simulation_parameters.w = [.1 .8 1.6];
hydro.hydro_coeffs.linear_restoring_stiffness = diag(1:6)/(fixture.rho*fixture.g);
hydro.hydro_coeffs.added_mass.all = reshape(1:108,6,6,3)/100;
hydro.hydro_coeffs.added_mass.inf_freq = reshape(1:36,6,6)/50;
hydro.hydro_coeffs.radiation_damping.all = reshape(1:108,6,6,3)/200;
hydro.hydro_coeffs.radiation_damping.impulse_response_fun = ...
    struct('t',[0 1 2],'K',reshape(1:108,6,6,3)/300);
for mode = 1:6
    for direction = 1:numel(hydro.simulation_parameters.direction)
        theta = hydro.simulation_parameters.direction(direction);
        w = hydro.simulation_parameters.w;
        h = (mode+w)*(1+.2*cosd(theta))+1i*(.1*mode-.2*w)*sind(theta);
        hydro.hydro_coeffs.excitation.re(mode,direction,:) = real(h)/(fixture.rho*fixture.g);
        hydro.hydro_coeffs.excitation.im(mode,direction,:) = -imag(h)/(fixture.rho*fixture.g);
    end
end
view = struct('omega_rad_s',[0;nativeOmega;1.6],'headings_deg',[-180;-170;13;180], ...
    're',zeros(6,4,5),'im',zeros(6,4,5),'md',zeros(6,4,5));
for mode = 1:6
    limit = hydro.hydro_coeffs.linear_restoring_stiffness(mode,3);
    for direction = 1:3
        for frequency = 1:5
            w = view.omega_rad_s(frequency);
            theta = view.headings_deg(direction);
            realPart = interp2(hydro.simulation_parameters.w,hydro.simulation_parameters.direction, ...
                squeeze(hydro.hydro_coeffs.excitation.re(mode,:,:)),max(w,.1),theta,'linear');
            imaginaryPart = interp2(hydro.simulation_parameters.w,hydro.simulation_parameters.direction, ...
                squeeze(hydro.hydro_coeffs.excitation.im(mode,:,:)),max(w,.1),theta,'linear');
            if w < .1
                realPart = limit+(w/.1)^2*(realPart-limit);
                imaginaryPart = (w/.1)^2*imaginaryPart;
            end
            view.re(mode,direction,frequency) = realPart;
            view.im(mode,direction,frequency) = imaginaryPart;
        end
    end
end
view.re(:,end,:) = view.re(:,1,:);
view.im(:,end,:) = view.im(:,1,:);
hydro.hydro_coeffs.excitation.component_view = view;
selected = getExcitationData(hydro,'spectrumImportFullDir');
waves = waveClass('spectrumImportFullDir');
waves.spectrumFile = fixture.file;
waves.setup(selected.w,'infinite',0,fixture.dt,numel(fixture.time)-1, ...
    fixture.time',fixture.g,fixture.rho);
end
