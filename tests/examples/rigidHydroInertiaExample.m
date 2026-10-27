function report = rigidHydroInertiaExample(outputDirectory)
% Smallest same-input release/corrected native acceleration witness for issue3.
if nargin < 1
    outputDirectory = tempname;
end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
originalPath = path;
cleanup = onCleanup(@() path(originalPath));
addpath(fullfile(root,'tests','helpers'));
report = runRigidHydroInertiaProbe(root,outputDirectory,4);
before = report.modes{1}.single_roll_torque_measured_dry_acceleration;
after = report.modes{2}.single_roll_torque_measured_dry_acceleration;
expected = report.modes{2}.single_roll_torque_expected_dry_acceleration;
fprintf('Same 1 N*m roll torque; initial angular acceleration [roll pitch yaw], rad/s^2\n');
fprintf('Release expression: %.17g %.17g %.17g\n',before(4:6));
fprintf('Reordered expression: %.17g %.17g %.17g\n',after(4:6));
fprintf('Independent M*a=w: %.17g %.17g %.17g\n',expected(4:6));
fprintf('Private numerical report: %s\n',fullfile(outputDirectory,'report.json'));
end
