function report = prepareRigidHydroInertiaLibrary(inputLibrary,outputDirectory)
% Draft recipe only: export untouched/control and one active rigid correction.
assert(isfile(inputLibrary),'Immutable source library is unavailable');
assert(~isfolder(outputDirectory) && ~isfile(outputDirectory),'Use a new private output directory');
library = 'WECSim_Lib_Body_Elements';
assert(~bdIsLoaded(library),'Use an isolated MATLAB process');
originalDirectory = pwd;
originalPath = path;
originalVisible = get(groot,'DefaultFigureVisible');
cleanup = onCleanup(@() restore_owned(library,originalDirectory,originalPath,originalVisible));
originalBytes = read_bytes(inputLibrary);
info = Simulink.MDLInfo(inputLibrary);
assert(strcmp(info.ReleaseName,'R2020b'),'Expected the release library file format');
mkdir(outputDirectory);
cd(outputDirectory);
set(groot,'DefaultFigureVisible','off');
expression = ['body.hydroForce.([''hf'' num2str(body.variableHydro.' ...
    'hydroForceIndexInitial)]).adjustedInertiaProducts'];
relative = '/Rigid Body/Hydrodynamic Body/Structure/Body Properties';
names = {'control','candidate'};
records = cell(1,2);
for mode = 1:2
    scratchDirectory = fullfile(outputDirectory,['scratch-' names{mode}]);
    exportDirectory = fullfile(outputDirectory,['export-' names{mode}]);
    mkdir(scratchDirectory);
    mkdir(exportDirectory);
    scratch = fullfile(scratchDirectory,[library '.slx']);
    exported = fullfile(exportDirectory,[library '.slx']);
    assert(~bdIsLoaded(library),'Prior owned library is still loaded');
    copyfile(inputLibrary,scratch);
    load_system(scratch);
    block = [library relative];
    assert(strcmp(get_param(block,'ProductsOfInertia'),expression),'Unexpected release expression');
    expected = expression;
    lock = get_param(library,'Lock');
    if mode == 2
        expected = [expression '([3 2 1])'];
        set_param(library,'Lock','off');
        set_param(block,'ProductsOfInertia',expected);
        set_param(library,'Lock',lock);
    end
    % No intermediate current-version save and no original-source overwrite.
    save_system(library,exported,'ExportToVersion','R2020b_SLX');
    close_system(library,0);
    assert(isequal(read_bytes(inputLibrary),originalBytes),'Immutable source changed');
    assert(isequal(read_bytes(scratch),originalBytes),'Unsaved scratch source changed');
    info = Simulink.MDLInfo(exported);
    assert(strcmp(info.ReleaseName,'R2020b'),'Export did not preserve the release-format label');
    exportedBytes = read_bytes(exported);
    load_system(exported);
    assert(strcmp(get_param(block,'ProductsOfInertia'),expected),'Reopened expression differs');
    assert(strcmp(get_param(library,'Lock'),lock),'Reopened lock differs');
    close_system(library,0);
    assert(isequal(read_bytes(exported),exportedBytes),'Reopening changed export bytes');
    records{mode} = struct('mode',names{mode},'export',exported,'expression',expected);
end
report = struct('status','private exports require strict audits and native regressions', ...
    'source',inputLibrary,'outputs',{records},'scope','active rigid Hydro only');
save(fullfile(outputDirectory,'preparation.mat'),'report','-v7');
end

function bytes = read_bytes(file)
fid = fopen(file,'rb');
assert(fid ~= -1,'Cannot read source/export');
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid,Inf,'*uint8');
end

function restore_owned(library,directory,searchPath,visible)
if bdIsLoaded(library)
    close_system(library,0);
end
cd(directory);
set(groot,'DefaultFigureVisible',visible);
path(searchPath);
end
