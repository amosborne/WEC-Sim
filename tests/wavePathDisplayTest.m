function tests = wavePathDisplayTest
% Regression for https://github.com/amosborne/WEC-Sim/issues/5.
tests = functiontests(localfunctions);
end

function setup(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
testCase.addTeardown(@() path(originalPath));
addpath(genpath(fullfile(root,'source')));
testCase.assertEqual(which('waveClass'),fullfile(root,'source','objects','waveClass.m'));
originalWarnings = warning;
[message,identifier] = lastwarn;
testCase.addTeardown(@() restore_warnings(originalWarnings,message,identifier));
warning('on','all');
end

function testCharPathsPrintedLiterally(testCase)
paths = fixture_paths();
for k = 1:numel(paths)
    verify_path(testCase,paths{k},paths{k});
end
end

function testStringPathsPrintedLiterally(testCase)
paths = fixture_paths();
for k = 1:numel(paths)
    verify_path(testCase,string(paths{k}),paths{k});
end
end

function testOtherWaveTypeDisplayUnchanged(testCase)
waves = waveClass('noWaveCIC');
lastwarn('','');
output = evalc('waves.listInfo();');
[message,identifier] = lastwarn;
testCase.verifyEmpty(message);
testCase.verifyEmpty(identifier);
expected = sprintf('\nWave Environment: \n\tWave Type                            = No Wave (Convolution Integral Calculation)\n');
testCase.verifyEqual(output,expected);
end

function paths = fixture_paths()
percent = char(37);
paths = {'C:\Users\alex\sea.dat', ...
    ['C:\Users\alex\100' percent 'boat\sea' percent 's-native' percent percent '.dat'], ...
    ['\\server\share\sea' percent 'g.dat']};
end

function verify_path(testCase,value,expected)
waves = waveClass('elevationImport');
waves.elevationFile = value;
lastwarn('','');
output = evalc('waves.listInfo();');
[message,identifier] = lastwarn;
testCase.verifyEmpty(message);
testCase.verifyEmpty(identifier);
testCase.verifyTrue(contains(output,['= ' expected '  ' newline]), ...
    'Imported filepath did not print verbatim');
end

function restore_warnings(state,message,identifier)
warning(state);
lastwarn(message,identifier);
end
