function report = importedExcitationGroupExample(forkRoot,outputDirectory)
% Same synthetic directional records on PR8-only and paired group sources.
assert(isfolder(forkRoot),'Selected fork is unavailable');
assert(~isfolder(outputDirectory) && ~isfile(outputDirectory),'Use a new private output directory');
originalPath = path;
cleanup = onCleanup(@() path(originalPath));
addpath(genpath(fullfile(forkRoot,'source')));
addpath(fullfile(forkRoot,'tests','helpers'));
assert(strcmp(which('bodyClass'),fullfile(forkRoot,'source','objects','bodyClass.m')), ...
    'Another bodyClass shadows the selected source; use a fresh process');
assert(strcmp(which('ImportedExcitationGroupProbe'), ...
    fullfile(forkRoot,'tests','helpers','ImportedExcitationGroupProbe.m')), ...
    'Another probe shadows the selected source');
mkdir(outputDirectory);
dt = 1;
time = (0:dt:4)';
lags = -1:1;
kernel = zeros(6,2,3);
for channel = 1:6
    kernel(channel,1,:) = channel*[1 2 3];
    kernel(channel,2,:) = (7-channel)*[3 -1 2];
end
body = ImportedExcitationGroupProbe(lags,kernel);
for j = 1:2
    rawTime = (-2:dt/j:6)';
    elevation = double(rawTime == j);
    file = fullfile(outputDirectory,sprintf('wave%d.txt',j));
    writematrix([rawTime elevation],file,'Delimiter','tab');
    waves(j) = waveClass('elevationImport');
    waves(j).elevationFile = file;
    waves(j).direction = 90*(j-1);
    waves(j).setup([1 2],inf,0,dt,numel(time)-1,time',1,1);
end
% Independent hand table: sample each file impulse at t-tau, multiply its
% own direction's three kernel weights and sum with dt=1. No native oracle.
expected = [1 2 3 4 5 6;20 19 18 17 16 15;-3 1 5 9 13 17;12 10 8 6 4 2;0 0 0 0 0 0];
actual = body.prepare(waves,dt);
assert(isequal(size(actual),size(expected)) && all(isfinite(actual),'all'), ...
    'Prepared force table is invalid');
difference = max(abs(actual-expected),[],'all');
report = struct('status','completed_preprocessing_example','time_s',time, ...
    'prepared_total',actual,'expected_total',expected,'maximum_abs_difference',difference, ...
    'matches_expected_within_1e_minus11',difference <= 1e-11,'direction_degrees',[0 90], ...
    'bodyClass_source',which('bodyClass'),'probe_source',which('ImportedExcitationGroupProbe'), ...
    'matlab_version',version, ...
    'scope','synthetic excitation preprocessing only; no applied bus, body dynamics or Topwater force table');
save(fullfile(outputDirectory,'report.mat'),'report','-v7');
fid = fopen(fullfile(outputDirectory,'report.json'),'w');
assert(fid ~= -1,'Cannot create private report');
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
fprintf('Prepared total (rows t=0:4, columns six modes):\n');
fprintf(' %.12g %.12g %.12g %.12g %.12g %.12g\n',actual');
fprintf('Maximum absolute difference from independent F1+F2 table: %.17g\n',difference);
end
