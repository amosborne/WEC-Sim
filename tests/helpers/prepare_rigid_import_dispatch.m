function report = prepare_rigid_import_dispatch(inputLibrary,outputDirectory)
% Supported API preparation only; root executes and audits private output.
assert(isfile(inputLibrary),'Immutable source library is unavailable');
assert(~isfolder(outputDirectory) && ~isfile(outputDirectory),'Use a new owned output directory');
mkdir(outputDirectory);
library = 'WECSim_Lib_Body_Elements';
assert(~bdIsLoaded(library),'Use an isolated model/class environment');
originalPath = path;
originalDirectory = pwd;
originalVisible = get(groot,'DefaultFigureVisible');
cleanup = onCleanup(@() restore_owned(library,originalPath,originalDirectory,originalVisible));
cd(outputDirectory);
set(groot,'DefaultFigureVisible','off');
outputLibrary = fullfile(outputDirectory,[library '.slx']);
copyfile(inputLibrary,outputLibrary);
beforeBytes = read_bytes(inputLibrary);
load_system(outputLibrary);
parent = [library '/Rigid Body/Hydrodynamic Body/Wave Diffraction and Excitation Force Calculation'];
mask = Simulink.Mask.get(parent);
before = mask.Initialization;
old = 'nWaves = size(waveGroup,2);';
replacement = 'nWaves = importedExcitationBranches(cb,waveGroup);';
assert(numel(strfind(before,old)) == 1,'Unexpected release rigid excitation mask header');
after = strrep(before,old,replacement);
lock = get_param(library,'Lock');
set_param(library,'Lock','off');
mask.Initialization = after;
set_param(library,'Lock',lock);
save_system(library,outputLibrary);
close_system(library,0);
load_system(outputLibrary);
reopened = Simulink.Mask.get(parent);
assert(strcmp(reopened.Initialization,after),'Reopened rigid header differs');
assert(isequal(read_bytes(inputLibrary),beforeBytes),'Immutable source library changed');
report = struct('input',inputLibrary,'output',outputLibrary,'path',parent, ...
    'before',before,'after',after,'scope','only rigid imported dispatch header intended; archive semantic audit still required');
save(fullfile(outputDirectory,'preparation.mat'),'report','-v7');
end

function bytes = read_bytes(file)
fid = fopen(file,'rb');
assert(fid ~= -1,'Cannot read source library');
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid,Inf,'*uint8');
end

function restore_owned(library,originalPath,originalDirectory,originalVisible)
if bdIsLoaded(library)
    close_system(library,0);
end
cd(originalDirectory);
set(groot,'DefaultFigureVisible',originalVisible);
path(originalPath);
end
