function tests = importedExcitationGroupTest
% Own-fork issue #2: directional sum and native total dispatch belong together.
tests = functiontests(localfunctions);
end

function setup(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
testCase.addTeardown(@() path(originalPath));
addpath(genpath(fullfile(root,'source')));
addpath(fullfile(root,'tests','helpers'));
testCase.assertEqual(which('bodyClass'),fullfile(root,'source','objects','bodyClass.m'));
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
testCase.TestData.folder = fixture.Folder;
testCase.TestData.root = root;
end

function testTwoDirectionalHistoriesSixChannels(testCase)
for dt = [1 .5]
    [body,waves,time,expected] = fixture_group(testCase,dt);
    testCase.verifyEqual(body.prepare(waves,dt),expected,'AbsTol',1e-11);
    testCase.verifyEqual(body.prepare(waves([2 1]),dt),expected,'AbsTol',1e-11);
    testCase.verifyEqual(body.prepare(waves(1),dt)+body.prepare(waves(2),dt),expected,'AbsTol',1e-11);
    testCase.verifyEqual(body.prepare(waves,dt),expected,'AbsTol',1e-11);
    testCase.verifyEqual(waves(1).waveAmpTime(:,1),time);
end
end

function testNativeAppliedTotalExactlyOnce(testCase)
[body,waves,time,expected] = fixture_group(testCase,.5);
body.prepare(waves,.5);
library = 'WECSim_Lib_Body_Elements';
testCase.assertFalse(bdIsLoaded(library),'Use an isolated library environment');
testCase.addTeardown(@() close_owned(library));
load_system(fullfile(testCase.TestData.root,'source','lib','WEC-Sim',[library '.slx']));
report = probeImportedExcitationBus(body,waves,time,library,testCase.TestData.folder);
testCase.verifyEqual(report.branch_count,1);
testCase.verifyEqual(report.fresh_count,1);
testCase.verifyEqual(report.regular_graph_count,2);
testCase.verifyEqual(report.restored_count,1);
testCase.verifyEqual(report.applied,expected,'AbsTol',1e-10);
testCase.verifyGreaterThan(max(abs(expected),[],'all'),0);
end

function testRejectDifferentOutputGrid(testCase)
[body,waves] = fixture_group(testCase,.5);
waves(2).setup([1 2],inf,0,1,4,0:4,1,1);
testCase.verifyError(@() body.prepare(waves,.5),'WECsim:ImportedExcitationOutputGrid');
end

function testRejectRewiredCloneWithoutDeletion(testCase)
[body,waves,time,expected] = fixture_group(testCase,.5);
body.prepare(waves,.5);
library = 'WECSim_Lib_Body_Elements';
testCase.assertFalse(bdIsLoaded(library),'Use an isolated library environment');
testCase.addTeardown(@() close_owned(library));
load_system(fullfile(testCase.TestData.root,'source','lib','WEC-Sim',[library '.slx']));
report = probeImportedExcitationBus(body,waves,time,library,testCase.TestData.folder,true);
testCase.verifyTrue(report.rewired_clone_rejected_without_deletion);
testCase.verifyEqual(report.branch_count,1);
testCase.verifyEqual(report.applied,expected,'AbsTol',1e-10);
end

function [body,waves,time,expected] = fixture_group(testCase,dt)
time = (0:dt:4)';
lags = -1:1;
kernel = zeros(6,2,3);
for channel = 1:6
    kernel(channel,1,:) = channel*[1 2 3];
    kernel(channel,2,:) = (7-channel)*[3 -1 2];
end
body = ImportedExcitationGroupProbe(lags,kernel);
expected = zeros(numel(time),6);
for j = 1:2
    rawTime = (-2:dt/j:6)';
    elevation = double(rawTime == j);
    file = [tempname(testCase.TestData.folder) '.txt'];
    writematrix([rawTime elevation],file,'Delimiter','tab');
    waves(j) = waveClass('elevationImport');
    waves(j).elevationFile = file;
    waves(j).direction = 90*(j-1);
    waves(j).setup([1 2],inf,0,dt,numel(time)-1,time',1,1);
    % Analytic triangular interpolation of a unit file impulse, independent of
    % native userDefinedExcitation and aggregation.
    for it = 1:numel(time)
        for tau = -1:dt:1
            eta = max(0,1-abs(time(it)-tau-j)/(dt/j));
            for channel = 1:6
                weight = interp1(lags,squeeze(kernel(channel,j,:)),tau,'linear');
                expected(it,channel) = expected(it,channel)+dt*eta*weight;
            end
        end
    end
end
end

function close_owned(library)
if bdIsLoaded(library)
    close_system(library,0);
end
end
