function tests = probeInitialSampleTest
% Pure array-shape regression; no Simscape model or numerical integration.
tests = functiontests(localfunctions);
end

function setup(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
originalPath = path;
testCase.addTeardown(@() path(originalPath));
addpath(fullfile(root,'tests','helpers'));
end

function testScalarTimeFirst(testCase)
log = fixture([0;.1],1,[7;999]);
testCase.verifyEqual(readProbeInitialSample(log,1),7);
end

function testVectorTimeFirst(testCase)
log = fixture([0;.1],3,[1 2 3;901 902 903]);
testCase.verifyEqual(readProbeInitialSample(log,3),[1;2;3]);
end

function testMatrixTimeLast(testCase)
data = cat(3,[1;2;3],[901;902;903]);
log = fixture([0;.1],[3 1],data);
testCase.verifyEqual(readProbeInitialSample(log,3),[1;2;3]);
end

function testMatrixTimeFirst(testCase)
data = cat(1,reshape([1 2 3],1,1,3),reshape([901 902 903],1,1,3));
log = fixture([0;.1],[1 3],data);
testCase.verifyEqual(readProbeInitialSample(log,3),[1;2;3]);
end

function testSingleMatrixSample(testCase)
log = fixture(0,[3 1],[1;2;3]);
testCase.verifyEqual(readProbeInitialSample(log,3),[1;2;3]);
end

function testRejectUndeclaredOrInconsistentLayout(testCase)
log = fixture([0;.1],3,[1;2;3;901;902;903]);
verify_rejection(testCase,@() readProbeInitialSample(log,3), ...
    'Unsupported native sensor time-axis layout');
log = fixture([0;.1],[3 1],cat(3,[1;2;3],[901;902;903]));
log.signals = rmfield(log.signals,'dimensions');
verify_rejection(testCase,@() readProbeInitialSample(log,3), ...
    'Signal dimensions must be declared');
end

function testRejectMissingZeroSample(testCase)
log = fixture([.1;.2],3,[1 2 3;901 902 903]);
verify_rejection(testCase,@() readProbeInitialSample(log,3), ...
    'Direct initial sample is unavailable');
end

function testRejectAmbiguousTimeAxis(testCase)
log = fixture([0;.1],[2 2],reshape(1:8,2,2,2));
verify_rejection(testCase,@() readProbeInitialSample(log,4), ...
    'Ambiguous native sensor time-axis layout');
end

function verify_rejection(testCase,operation,expectedMessage)
failure = [];
try
    operation();
catch caught
    failure = caught;
end
testCase.assertNotEmpty(failure,'The invalid sample must be rejected');
testCase.verifyEqual(failure.message,expectedMessage);
end

function log = fixture(time,dimensions,values)
log = struct('time',time,'signals',struct('dimensions',dimensions,'values',values));
end
