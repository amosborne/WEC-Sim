function tests = importedExcitationHistoryTest
% Regression for https://github.com/amosborne/WEC-Sim/issues/1.
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
state = warning;
[message,identifier] = lastwarn;
testCase.addTeardown(@() restore_warnings(state,message,identifier));
warning('on','WECsim:ImportedExcitationRecordSupport');
end

function testFullFileHistorySixChannels(testCase)
for dt = [1 .5]
    times = (0:dt:10)';
    rawTime = (-3:dt:13)';
    lags = -2:2;
    kernel = channel_kernel(lags);
    for impulse = [-1 5 11]
        history = [rawTime double(rawTime == impulse)];
        waves = fixture_wave(testCase,history,times,dt,0);
        original = waves.waveAmpTime;
        body = ImportedExcitationHistoryProbe(lags,kernel);
        actual = body.prepare(waves,dt,0);
        testCase.verifyEqual(actual,reference_force(times,history,lags,kernel,dt,0),'AbsTol',1e-11);
        testCase.verifyEqual(waves.waveAmpTime,original);
    end
end
end

function testAsymmetricAndOneSidedLags(testCase)
for dt = [1 .5]
    times = (0:dt:8)';
    rawTime = (-5:dt:13)';
    history = [rawTime double(rawTime == 3)];
    for support = {[-1 0 1 2],[1 2 3],[-3 -2 -1]}
        lags = support{1};
        kernel = channel_kernel(lags);
        waves = fixture_wave(testCase,history,times,dt,0);
        body = ImportedExcitationHistoryProbe(lags,kernel);
        testCase.verifyEqual(body.prepare(waves,dt,0), ...
            reference_force(times,history,lags,kernel,dt,0),'AbsTol',1e-11);
    end
end
end

function testOffGridLagsKeepOriginalSampling(testCase)
for dt = [1 .5]
    times = (0:dt:6)';
    rawTime = (-4:.25:10)';
    history = [rawTime 1+.2*rawTime];
    lags = [-.75 .25 1.25];
    kernel = channel_kernel(lags);
    waves = fixture_wave(testCase,history,times,dt,0);
    body = ImportedExcitationHistoryProbe(lags,kernel);
    testCase.verifyEqual(body.prepare(waves,dt,0), ...
        reference_force(times,history,lags,kernel,dt,0),'AbsTol',1e-11);
end
end

function testSourceTimeRampWithNegativeHistoryAndNonzeroStart(testCase)
dt = .5;
times = (2:dt:6)';
rawTime = (-4:dt:10)';
history = [rawTime 1+.1*rawTime];
lags = -2:3;
kernel = channel_kernel(lags);
waves = fixture_wave(testCase,history,times,dt,4);
original = waves.waveAmpTime;
body = ImportedExcitationHistoryProbe(lags,kernel);
testCase.verifyEqual(body.prepare(waves,dt,4), ...
    reference_force(times,history,lags,kernel,dt,4),'AbsTol',1e-11);
testCase.verifyEqual(waves.waveAmpTime,original);
end

function testZeroRampRetainsNegativeHistory(testCase)
times = (0:.5:4)';
rawTime = (-3:.5:7)';
history = [rawTime double(rawTime == -1)];
lags = -2:2;
kernel = channel_kernel(lags);
waves = fixture_wave(testCase,history,times,.5,0);
body = ImportedExcitationHistoryProbe(lags,kernel);
expected = reference_force(times,history,lags,kernel,.5,0);
testCase.verifyGreaterThan(max(abs(expected),[],'all'),0);
testCase.verifyEqual(body.prepare(waves,.5,0),expected,'AbsTol',1e-11);
end

function testLegacyAlreadyRampedInputNotRampedTwice(testCase)
dt = .5;
times = (-3:dt:7)';
ramped = (1-cos(pi*times/4))/2;
ramped(times >= 4) = 1;
table = [times ramped];
lags = [-1 0 1];
kernel = channel_kernel(lags);
body = ImportedExcitationHistoryProbe(lags,kernel);
testCase.verifyWarning(@() body.legacy(table,dt),'WECsim:ImportedExcitationRecordSupport');
warning('off','WECsim:ImportedExcitationRecordSupport');
actual = body.legacy(table,dt);
testCase.verifyEqual(actual,reference_force(times,table,lags,kernel,dt,0),'AbsTol',1e-11);
end

function testPartialRecordZeroExtensionWarnsOnce(testCase)
times = (0:.5:4)';
history = [times ones(size(times))];
lags = [-1 0 1];
kernel = channel_kernel(lags);
waves = fixture_wave(testCase,history,times,.5,0);
body = ImportedExcitationHistoryProbe(lags,kernel);
lastwarn('','');
output = evalc('actual = body.prepare(waves,.5,0);');
[~,identifier] = lastwarn;
testCase.verifyEqual(identifier,'WECsim:ImportedExcitationRecordSupport');
testCase.verifyEqual(count(output,'Excitation queries need'),1);
testCase.verifyEqual(actual,reference_force(times,history,lags,kernel,.5,0),'AbsTol',1e-11);
end

function testNonfiniteInputIsRejected(testCase)
table = [(0:4)' ones(5,1)];
body = ImportedExcitationHistoryProbe(-1:1,channel_kernel(-1:1));
for column = 1:2
    for value = [NaN Inf]
        invalid = table;
        invalid(3,column) = value;
        testCase.verifyError(@() body.raw(table,1,invalid,0),'WECsim:InvalidImportedExcitationData');
    end
end
end

function testInvalidHistoryTableIsRejected(testCase)
table = [(0:4)' ones(5,1)];
body = ImportedExcitationHistoryProbe(-1:1,channel_kernel(-1:1));
for invalid = {table(:,1),table(1,:),[0 1;0 2],complex(table,ones(size(table)))}
    testCase.verifyError(@() body.raw(table,1,invalid{1},0),'WECsim:InvalidImportedExcitationData');
end
end

function testInvalidKernelIsRejected(testCase)
table = [(0:4)' ones(5,1)];
kernel = channel_kernel(-1:1);
kernel(2,2) = NaN;
body = ImportedExcitationHistoryProbe(-1:1,kernel);
testCase.verifyError(@() body.raw(table,1,table,0),'WECsim:InvalidExcitationKernel');
body = ImportedExcitationHistoryProbe(-1:1,channel_kernel(-1:1));
for dt = [0 -1 NaN Inf]
    testCase.verifyError(@() body.raw(table,dt,table,0),'WECsim:InvalidExcitationKernel');
end
end

function testRegularWavePathControl(testCase)
waves = waveClass('regularCIC');
waves.period = 2*pi/1.5;
waves.height = 1;
waves.direction = 0;
waves.setup([1 2],inf,0,.5,8,0:.5:4,1,1);
body = ImportedExcitationHistoryProbe(-1:1,channel_kernel(-1:1));
body.prepare(waves,.5,0);
force = body.hydroForce.hf1.fExt;
testCase.verifyEqual(force.re,1:6);
testCase.verifyEqual(force.im,-2*(1:6));
testCase.verifyEqual(force.md,3*(1:6));
end

function waves = fixture_wave(testCase,history,times,dt,rampTime)
file = [tempname(testCase.TestData.folder) '.txt'];
writematrix(history,file,'Delimiter','tab');
waves = waveClass('elevationImport');
waves.elevationFile = file;
waves.direction = 0;
waves.setup([1 2],inf,rampTime,dt,numel(times)-1,times',1,1);
end

function kernel = channel_kernel(lags)
channels = (1:6)';
kernel = channels*(2+lags)+channels.^2*(1+.1*lags.^2);
end

function force = reference_force(times,history,lags,kernel,dt,rampTime)
% Independent scalar, piecewise-linear sampling rather than interp1/broadcast.
force = zeros(numel(times),6);
for it = 1:numel(times)
    for tau = min(lags):dt:max(lags)
        sourceTime = times(it)-tau;
        amplitude = scalar_sample(history,sourceTime);
        ramp = 1;
        if rampTime > 0 && sourceTime < rampTime
            ramp = (1-cos(pi*sourceTime/rampTime))/2;
        end
        for channel = 1:6
            weight = scalar_sample([lags(:) kernel(channel,:)'],tau);
            force(it,channel) = force(it,channel)+dt*weight*amplitude*ramp;
        end
    end
end
end

function value = scalar_sample(table,time)
if time < table(1,1) || time > table(end,1)
    value = 0;
    return
end
index = find(table(:,1) <= time,1,'last');
value = table(index,2);
if index < size(table,1)
    fraction = (time-table(index,1))/(table(index+1,1)-table(index,1));
    value = value+fraction*(table(index+1,2)-value);
end
end

function restore_warnings(state,message,identifier)
warning(state);
lastwarn(message,identifier);
end
