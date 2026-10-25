function tests = readCapytaineHandlesTest
% Regression for https://github.com/amosborne/WEC-Sim/issues/4.
tests = functiontests(localfunctions);
end

function setup(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
testCase.addTeardown(@() path(originalPath));
addpath(genpath(fullfile(root,'source')));
testCase.assertEqual(which('readCAPYTAINE'),fullfile(root,'source','functions','BEMIO','readCAPYTAINE.m'));
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
before = open_ids();
testCase.addTeardown(@() close_fixture_handles(fixture.Folder,before));
sentinelPath = fullfile(fixture.Folder,'unrelated-user-file.txt');
sentinel = fopen(sentinelPath,'w+');
testCase.assertNotEqual(sentinel,-1);
testCase.TestData.root = root;
testCase.TestData.folder = fixture.Folder;
testCase.TestData.sentinel = sentinel;
testCase.TestData.sentinelPath = sentinelPath;
testCase.TestData.expectedIds = open_ids();
end

function testRepeatedSingleBodyImport(testCase)
file = fixture_input(testCase,'sphere');
first = readCAPYTAINE(struct(),file);
verify_inventory(testCase);
second = readCAPYTAINE(struct(),file);
verify_inventory(testCase);
testCase.verifyEqual(second,first);
verify_added_mass(testCase,first,file);
end

function testRepeatedMultiBodyImport(testCase)
file = fixture_input(testCase,'rm3');
first = readCAPYTAINE(struct(),file);
verify_inventory(testCase);
second = readCAPYTAINE(struct(),file);
verify_inventory(testCase);
testCase.verifyEqual(first.Nb,2);
testCase.verifyEqual(second,first);
end

function testMalformedKhDoesNotLeak(testCase)
file = fixture_input(testCase,'sphere');
write_text(fullfile(fileparts(file),'KH.dat'),'0 0 0 0 0 0');
verify_failed_import(testCase,file);
end

function testMalformedHydrostaticsDoesNotLeak(testCase)
file = fixture_input(testCase,'sphere');
write_text(fullfile(fileparts(file),'Hydrostatics.dat'),'malformed');
verify_failed_import(testCase,file);
end

function testMissingLaterBodySidecarDoesNotLeak(testCase)
file = fixture_input(testCase,'rm3');
delete(fullfile(fileparts(file),'KH_1.dat'));
verify_failed_import(testCase,file);
end

function testImportedFixturesCanBeRenamedAndDeleted(testCase)
file = fixture_input(testCase,'sphere');
readCAPYTAINE(struct(),file);
verify_inventory(testCase);
files = dir(fileparts(file));
for k = 1:numel(files)
    if files(k).isdir
        continue
    end
    source = fullfile(files(k).folder,files(k).name);
    renamed = [source '.renamed'];
    [ok,message] = movefile(source,renamed);
    testCase.assertTrue(ok,message);
    delete(renamed);
    testCase.verifyFalse(isfile(renamed));
end
verify_inventory(testCase);
end

function file = fixture_input(testCase,name)
source = fullfile(testCase.TestData.root,'examples','BEMIO','CAPYTAINE',name,'outputs');
destination = fullfile(testCase.TestData.folder,name);
mkdir(destination);
files = dir(source);
for k = 1:numel(files)
    if ~files(k).isdir && (endsWith(files(k).name,'.nc') || endsWith(files(k).name,'.dat'))
        copyfile(fullfile(source,files(k).name),destination);
    end
end
file = fullfile(destination,[name '_hydrodynamics.nc']);
testCase.assertTrue(isfile(file),'Checked-in CAPYTAINE fixture is missing');
end

function verify_failed_import(testCase,file)
failed = false;
try
    readCAPYTAINE(struct(),file);
catch
    failed = true;
end
testCase.verifyTrue(failed,'Malformed or incomplete fixture unexpectedly imported');
verify_inventory(testCase);
end

function verify_inventory(testCase)
testCase.verifyEqual(open_ids(),testCase.TestData.expectedIds);
testCase.verifyEqual(fopen(testCase.TestData.sentinel),testCase.TestData.sentinelPath);
testCase.verifyEqual(fseek(testCase.TestData.sentinel,0,'eof'),0);
testCase.verifyGreaterThan(fprintf(testCase.TestData.sentinel,'still open\n'),0);
end

function verify_added_mass(testCase,hydro,file)
info = ncinfo(file,'added_mass');
dimensions = {info.Dimensions.Name};
order = [find(strcmp(dimensions,'influenced_dof')) ...
         find(strcmp(dimensions,'radiating_dof')) ...
         find(strcmp(dimensions,'omega'))];
order = [order setdiff(1:numel(dimensions),order,'stable')];
expected = permute(ncread(file,'added_mass'),order);
frequencies = ncread(file,'omega');
expected = reshape(expected,6,6,numel(frequencies));
[foundFrequencies,w] = ismember(hydro.w,frequencies);
modes = ["surge","sway","heave","roll","pitch","yaw"];
influenced = strip(erase(lower(string(ncread(file,'influenced_dof')')),char(0)));
radiating = strip(erase(lower(string(ncread(file,'radiating_dof')')),char(0)));
[foundInfluenced,i] = ismember(modes,influenced);
[foundRadiating,j] = ismember(modes,radiating);
testCase.assertTrue(all(foundInfluenced) && all(foundRadiating) && all(foundFrequencies));
testCase.verifyEqual(hydro.A,expected(i,j,w)/double(hydro.rho),'AbsTol',0);
end

function ids = open_ids()
if exist('openedFiles','builtin') || exist('openedFiles','file')
    ids = openedFiles;
else
    ids = fopen('all');
end
ids = sort(ids(:));
end

function close_fixture_handles(folder,before)
ids = open_ids();
for k = 1:numel(ids)
    name = fopen(ids(k));
    if ~ismember(ids(k),before) && startsWith(name,[folder filesep])
        fclose(ids(k));
    end
end
end

function write_text(file,text)
fid = fopen(file,'w');
assert(fid ~= -1,'Could not create malformed test fixture');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',text);
end
