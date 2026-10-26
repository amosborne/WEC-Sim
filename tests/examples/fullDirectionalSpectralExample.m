function report = fullDirectionalSpectralExample(forkRoot,outputDirectory,runNativeBus,directions)
% Same physical inputs before/after both focused FullDir corrections.
if nargin < 3
    runNativeBus = true;
end
if nargin < 4
    directions = [0;90];
end
assert(~isfolder(outputDirectory),'Use a new output directory.');
mkdir(outputDirectory);
originalPath = path;
originalRandom = rng;
cleanup = onCleanup(@() restore_state(originalPath,originalRandom));
addpath(genpath(fullfile(forkRoot,'source')));
addpath(fullfile(forkRoot,'tests','helpers'));
addpath(fileparts(mfilename('fullpath')));
assert(strcmp(which('bodyClass'),fullfile(forkRoot,'source','objects','bodyClass.m')));
assert(strcmp(which('waveClass'),fullfile(forkRoot,'source','objects','waveClass.m')));
assert(strcmp(which('irregExcFullDirF'),fullfile(forkRoot, ...
    'source','functions','simulink','model','irregExcFullDirF.m')));
fixture = fullDirectionalSpectralFixture(outputDirectory,directions,true);
waves = waveClass('spectrumImportFullDir');
waves.spectrumFile = fixture.file;
waves.phaseSeed = 17;
waves.setup(fixture.omega','infinite',0,fixture.dt,numel(fixture.time)-1, ...
    fixture.time',fixture.g,fixture.rho);
probe = FullDirectionalSpectralProbe(fixture.hydro);
probe.prepare(waves,fixture.rho,fixture.g);
actualForce = probe.evaluate(waves,fixture.time);
expectedField = scalar_field(fixture,fixture.phases);
expectedForce = scalar_force(fixture,fixture.phases);
% Actual random/supplied phases isolate direction weighting from phase import.
expectedForceActualPhase = scalar_force(fixture,waves.phase);
reconstructedAmplitude = sqrt(waves.amplitude.*waves.dOmega.*waves.dTheta');
actualField = zeros(size(expectedField));
for k = 1:numel(fixture.time)
    actualField(k,:) = waves.waveElevationGrid(fixture.time(k), ...
        fixture.positions(:,1)',fixture.positions(:,2)',k,fixture.g);
end
report.scope = 'Synthetic phase/direction-width component proof only; no packet, IRF or dynamics';
report.transfer_scope = 'Distinct complex six-mode and per-heading H at exact nodes; no low-frequency or interpolation qualification';
report.time_s = fixture.time;
report.input_phase_rad = fixture.phases;
report.prepared_phase_rad = waves.phase;
report.phase_max_abs_difference = max(abs(waves.phase-fixture.phases),[],'all');
report.amplitude_max_abs_difference = max(abs(reconstructedAmplitude-fixture.amplitudes),[],'all');
report.field_max_abs_difference = max(abs(actualField-expectedField),[],'all');
report.origin_max_abs_difference = max(abs(waves.waveAmpTime(:,2)-expectedField(:,1)));
report.native_force = actualForce;
report.expected_force = expectedForce;
report.expected_force_actual_prepared_phase = expectedForceActualPhase;
report.force_max_abs_difference = max(abs(actualForce-expectedForce),[],'all');
report.weight_only_max_abs_difference = max(abs(actualForce-expectedForceActualPhase),[],'all');
report.phase_pass = report.phase_max_abs_difference == 0;
report.field_pass = report.field_max_abs_difference <= 1e-12 && report.origin_max_abs_difference <= 1e-12;
report.weight_pass = report.weight_only_max_abs_difference <= 1e-10;
report.combined_first_order_pass = report.phase_pass && report.field_pass && report.weight_pass ...
    && report.amplitude_max_abs_difference <= 1e-12 && report.force_max_abs_difference <= 1e-10;
report.native_bus_executed = runNativeBus;
if runNativeBus
    busForce = probeFullDirectionalSpectralBus(probe,waves,fixture.time,forkRoot);
    report.native_bus_force = busForce;
    report.bus_vs_native_function_max_abs_difference = max(abs(busForce-actualForce),[],'all');
    report.bus_vs_physical_components_max_abs_difference = max(abs(busForce-expectedForce),[],'all');
    report.native_bus_pass = report.bus_vs_native_function_max_abs_difference <= 1e-10 ...
        && report.bus_vs_physical_components_max_abs_difference <= 1e-10;
    report.combined_pass = report.combined_first_order_pass && report.native_bus_pass;
end
save(fullfile(outputDirectory,'arrays.mat'),'fixture','expectedField','expectedForce', ...
    'actualField','actualForce','expectedForceActualPhase','report','-v7');
file = fopen(fullfile(outputDirectory,'report.json'),'w');
assert(file >= 0,'Cannot open report.');
closeFile = onCleanup(@() fclose(file));
fprintf(file,'%s\n',jsonencode(report));
clear cleanup
end

function value = scalar_field(fixture,phase)
value = zeros(numel(fixture.time),size(fixture.positions,1));
for it = 1:numel(fixture.time)
    for point = 1:size(fixture.positions,1)
        for direction = 1:numel(fixture.directions)
            projection = fixture.positions(point,:)* ...
                [cosd(fixture.directions(direction));sind(fixture.directions(direction))];
            for frequency = 1:numel(fixture.omega)
                w = fixture.omega(frequency);
                value(it,point) = value(it,point)+fixture.amplitudes(frequency,direction)* ...
                    cos(w*fixture.time(it)-w^2/fixture.g*projection+phase(frequency,direction));
            end
        end
    end
end
end

function force = scalar_force(fixture,phase)
force = zeros(numel(fixture.time),6);
for it = 1:numel(fixture.time)
    for mode = 1:6
        for direction = 1:numel(fixture.directions)
            for frequency = 1:numel(fixture.omega)
                angle = fixture.omega(frequency)*fixture.time(it)+phase(frequency,direction);
                transfer = fixture.transfer(frequency,direction,mode);
                force(it,mode) = force(it,mode)+fixture.amplitudes(frequency,direction)* ...
                    (real(transfer)*cos(angle)+imag(transfer)*sin(angle));
            end
        end
    end
end
end

function restore_state(originalPath,originalRandom)
path(originalPath);
rng(originalRandom);
end
