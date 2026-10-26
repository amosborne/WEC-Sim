function report = runRigidHydroInertiaProbe(forkRoot,outputDirectory,basisIndices)
% Active Rigid Hydro File Solid witness, ported from measured standalone source.
% Call in an isolated MATLAB process. No WEC initialization or body trajectory.
if nargin < 3
    basisIndices = 1:6;
end
assert(isequal(basisIndices,1:6) || isequal(basisIndices,4), ...
    'Choose all six independent wrenches or the single roll-torque example');
assert(isfolder(forkRoot),'WEC-Sim source checkout is unavailable');
assert(~isfolder(outputDirectory) && ~isfile(outputDirectory), ...
    'Use a new owned output directory');
mkdir(outputDirectory);
originalPath = path;
originalDirectory = pwd;
originalVisible = get(groot,'DefaultFigureVisible');
settings = onCleanup(@() restore_settings(originalPath,originalDirectory,originalVisible));
cd(outputDirectory);
set(groot,'DefaultFigureVisible','off');
addpath(genpath(fullfile(forkRoot,'source')));
addpath(fileparts(mfilename('fullpath')));
assert(strcmp(which('bodyClass'),fullfile(forkRoot,'source','objects','bodyClass.m')), ...
    'A different WEC-Sim bodyClass shadows the selected source');
library = 'WECSim_Lib_Body_Elements';
assert(~bdIsLoaded(library),'Selected WEC library is already loaded; use an isolated process');
owned = onCleanup(@() close_owned(library));
file = fullfile(forkRoot,'source','lib','WEC-Sim',[library '.slx']);
originalBytes = read_bytes(file);
load_system(file);
assert(strcmp(get_param(library,'FileName'),file),'A different WEC library was loaded');
boundary = 'Rigid Body/Hydrodynamic Body/Structure/Body Properties';
source = [library '/' boundary];
oldExpression = ['body.hydroForce.([''hf'' num2str(body.variableHydro.' ...
    'hydroForceIndexInitial)]).adjustedInertiaProducts'];
sourceExpression = get_param(source,'ProductsOfInertia');
assert(strcmp(sourceExpression,oldExpression) || strcmp(sourceExpression,[oldExpression '([3 2 1])']), ...
    'Witness requires the release expression or its one reorder correction');
assert(strcmp(get_param(source,'InertiaType'),'Custom'),'Source does not use custom inertia');
assert(strcmp(get_param(source,'CenterOfMass'),'[0 0 0]'),'Unexpected source CG convention');
assert(strcmp(get_param(source,'MassUnits'),'kg') && ...
    strcmp(get_param(source,'MomentsOfInertiaUnits'),'kg*m^2') && ...
    strcmp(get_param(source,'ProductsOfInertiaUnits'),'kg*m^2'),'Unexpected source inertia units');
M = blkdiag(7*eye(3),[10 1.1 -1.3;1.1 12 1.7;-1.3 1.7 14]);
A = diag([.2 .3 .4 .5 .6 .7]);
A(1,4) = .012; A(4,1) = .017;
A(4,5) = .04; A(5,4) = .03;
A(4,6) = -.02; A(6,4) = -.018;
A(5,6) = .025; A(6,5) = .021;
principal = eig(M(4:6,4:6));
assert(all(principal > 0) && 2*max(principal) < sum(principal), ...
    'Dry inertia must be physically admissible');
assert(norm(A-A','fro') > 0,'Residual fixture must be nonsymmetric');
bodies = {RigidInertiaProbeBody(M,zeros(6)),RigidInertiaProbeBody(M,A)};
expected = {M,M+A};
stl = fullfile(outputDirectory,'fixture.stl');
write_tetrahedron(stl);
load_system('sm_lib');
load_system('nesl_utility');
report = struct('status','running','boundary',boundary,'release','a23d2993807410fe78cc63546c1ba9d81912024f', ...
    'source_expression',sourceExpression,'basis_indices',basisIndices,'dry_matrix',M, ...
    'synthetic_added_mass',A,'modes',{{}}, ...
    'scope','isolated active rigid Solid; residual composition is algebraic, not a simulated hydro force');
for mode = 1:2
    reorder = mode == 2;
    response = zeros(6,numel(basisIndices),2);
    records = cell(1,numel(basisIndices));
    for column = 1:numel(basisIndices)
        basis = basisIndices(column);
        [~,suffix] = fileparts(tempname(outputDirectory));
        model = ['rigid_probe_' suffix];
        assert(~bdIsLoaded(model),'Owned probe name is already loaded');
        cleanup = onCleanup(@() close_owned(model));
        new_system(model);
        workspace = get_param(model,'ModelWorkspace');
        copied = cell(1,2);
        for c = 1:2
            variable = ['fixtureBody' num2str(c)];
            assignin(workspace,variable,bodies{c});
            copied{c} = build_component(model,['Case' num2str(c)],variable, ...
                source,sourceExpression,oldExpression,reorder,stl,basis);
        end
        set_param(model,'SimMechanicsOpenEditorOnUpdate','off','Solver','ode15s', ...
            'StopTime','1e-4','MaxStep','1e-4','RelTol','1e-10','AbsTol','1e-12', ...
            'ReturnWorkspaceOutputs','on');
        result = sim(model);
        initial = cell(1,2);
        for c = 1:2
            prefix = ['case' num2str(c) '_'];
            acceleration = [first_sample(result,[prefix 'ax'],1); ...
                first_sample(result,[prefix 'ay'],1);first_sample(result,[prefix 'az'],1); ...
                first_sample(result,[prefix 'b'],3)];
            velocity = [first_sample(result,[prefix 'vx'],1); ...
                first_sample(result,[prefix 'vy'],1);first_sample(result,[prefix 'vz'],1); ...
                first_sample(result,[prefix 'w'],3)];
            position = [first_sample(result,[prefix 'px'],1); ...
                first_sample(result,[prefix 'py'],1);first_sample(result,[prefix 'pz'],1)];
            quaternion = first_sample(result,[prefix 'Q'],4);
            assert(norm(velocity,Inf) <= 1e-10 && norm(position,Inf) <= 1e-10, ...
                'Initial native CG position/velocity is not zero');
            assert(abs(abs(quaternion(1))-1) <= 1e-10 && norm(quaternion(2:4),Inf) <= 1e-10, ...
                'Initial native orientation is not identity');
            assert(all(isfinite(acceleration)),'Native acceleration is nonfinite');
            response(:,column,c) = acceleration;
            initial{c} = struct('acceleration',acceleration,'velocity',velocity, ...
                'position',position,'orientation_wxyz',quaternion);
        end
        record = struct('mode',mode,'basis',basis,'wrench',unit_wrench(basis), ...
            'copied_boundary',{copied},'initial',{initial});
        records{column} = record;
        save(fullfile(outputDirectory,sprintf('mode%d-basis%d.mat',mode,basis)),'record','-v7');
        close_system(model,0);
        clear cleanup
    end
    comparisons = cell(1,2);
    for c = 1:2
        data = struct('native_acceleration_columns',response(:,:,c), ...
            'actual_residual',bodies{c}.hydroForce.hf1.fAddedMass, ...
            'expected_full_matrix',expected{c},'public_products',bodies{c}.inertiaProducts, ...
            'adjusted_products',bodies{c}.hydroForce.hf1.adjustedInertiaProducts);
        if isequal(basisIndices,1:6)
            assert(rcond(response(:,:,c)) > 1e-8,'Native measured acceleration response is singular');
            data.inferred_native_matrix = response(:,:,c) \ eye(6);
            data.reconstructed_full_matrix = data.inferred_native_matrix+data.actual_residual;
            data.maximum_abs_error = max(abs(data.reconstructed_full_matrix-expected{c}),[],'all');
        end
        comparisons{c} = data;
    end
    dryRollColumn = find(basisIndices == 4,1);
    report.modes{mode} = struct('reordered',reorder,'cases',{comparisons},'runs',{records}, ...
        'single_roll_torque_measured_dry_acceleration',response(:,dryRollColumn,1), ...
        'single_roll_torque_expected_dry_acceleration',M \ unit_wrench(4));
end
assert(isequal(read_bytes(file),originalBytes),'Source library bytes changed');
assert(strcmp(get_param(source,'ProductsOfInertia'),sourceExpression),'Source library expression changed');
assert(strcmp(get_param(library,'Dirty'),'off'),'Source library became modified');
report.status = 'completed_measurement';
save(fullfile(outputDirectory,'report.mat'),'report','-v7');
fid = fopen(fullfile(outputDirectory,'report.json'),'w');
assert(fid ~= -1,'Cannot write owned report');
jsonCleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(report));
end

function audit = build_component(model,name,variable,source,sourceExpression,oldExpression,reorder,stl,basis)
parent = [model '/' name];
add_block('built-in/Subsystem',parent);
mask = Simulink.Mask.create(parent);
mask.addParameter('Type','edit','Name','body','Value',variable,'Evaluate','on');
solid = [parent '/Solid'];
add_block(source,solid);
assert(strcmp(get_param(solid,'MaskType'),'File Solid'),'Boundary copy is not a native File Solid');
assert(strcmp(get_param(solid,'ProductsOfInertia'),sourceExpression),'Copy lost the actual source expression');
set_param(solid,'ExtGeomFileName',stl,'GraphicType','None');
before = inertia_parameters(solid);
targetExpression = oldExpression;
if reorder
    targetExpression = [oldExpression '([3 2 1])'];
end
if ~strcmp(get_param(solid,'ProductsOfInertia'),targetExpression)
    set_param(solid,'ProductsOfInertia',targetExpression);
end
after = inertia_parameters(solid);
control = after;
control.ProductsOfInertia = before.ProductsOfInertia;
assert(isequal(before,control),'A copied inertia parameter other than product order changed');
audit = struct('before',before,'after',after);
joint = [parent '/Joint'];
add_block('sm_lib/Joints/6-DOF Joint',joint);
for primitive = {'Px','Py','Pz'}
    p = primitive{1};
    set_param(joint,[p 'TorqueActuationMode'],'InputTorque', ...
        [p 'MotionActuationMode'],'ComputedMotion',[p 'SpringStiffness'],'0', ...
        [p 'DampingCoefficient'],'0',[p 'LowerLimitSpecify'],'off',[p 'UpperLimitSpecify'],'off', ...
        [p 'PositionTargetSpecify'],'on',[p 'PositionTargetValue'],'0', ...
        [p 'VelocityTargetSpecify'],'on',[p 'VelocityTargetValue'],'0', ...
        [p 'SenseAcceleration'],'on',[p 'SenseVelocity'],'on',[p 'SensePosition'],'on');
end
set_param(joint,'JointMode','Normal','SphTorqueActuationMode','InputTorque', ...
    'SphActuateTorque','on','SphActuateTorqueX','off','SphActuateTorqueY','off', ...
    'SphActuateTorqueZ','off','SphActuationFrame','BaseFrame','SphSensingFrame','BaseFrame', ...
    'SphPositionTargetSpecify','on','SphPositionTargetRotationMethod','Quaternion', ...
    'SphPositionTargetQuaternion','[1 0 0 0]','SphVelocityTargetSpecify','on', ...
    'SphVelocityTargetValue','[0 0 0]','SphSpringStiffness','0','SphDampingCoefficient','0', ...
    'SphLowerLimitSpecify','off','SphUpperLimitSpecify','off', ...
    'SphSenseAcceleration','on','SphSenseVelocity','on','SphSensePosition','on');
world = [parent '/World'];
mechanism = [parent '/Mechanism'];
solver = [parent '/Solver'];
add_block('sm_lib/Frames and Transforms/World Frame',world);
add_block(sprintf('sm_lib/Utilities/Mechanism\nConfiguration'),mechanism);
set_param(mechanism,'UniformGravity','None');
add_block('nesl_utility/Solver Configuration',solver);
connect_ports(world,one_port(world),joint,named_port(joint,'B'));
connect_ports(joint,named_port(joint,'F'),solid,named_port(solid,'R'));
connect_ports(world,one_port(world),mechanism,one_port(mechanism));
connect_ports(world,one_port(world),solver,one_port(solver));
wrench = unit_wrench(basis);
for k = 1:3
    add_input(parent,joint,['f' char('x'+k-1)],wrench(k),'N');
end
add_input(parent,joint,'t',wrench(4:6),'N*m');
labels = {'ax','ay','az','b','vx','vy','vz','w','px','py','pz','Q'};
units = {'m/s^2','m/s^2','m/s^2','rad/s^2','m/s','m/s','m/s','rad/s','m','m','m','1'};
for k = 1:numel(labels)
    add_output(parent,joint,labels{k},units{k},[lower(name) '_' labels{k}]);
end
end

function data = inertia_parameters(block)
names = {'InertiaType','Mass','MassUnits','CenterOfMass','CenterOfMassUnits', ...
    'MomentsOfInertia','MomentsOfInertiaUnits','ProductsOfInertia','ProductsOfInertiaUnits'};
data = struct();
for k = 1:numel(names)
    data.(names{k}) = get_param(block,names{k});
end
end

function add_input(parent,joint,label,value,unit)
constant = [parent '/Input_' label];
converter = [parent '/ToPS_' label];
add_block('simulink/Sources/Constant',constant,'Value',mat2str(value,17));
add_block('nesl_utility/Simulink-PS Converter',converter,'Unit',unit);
add_line(parent,['Input_' label '/1'],['ToPS_' label '/1']);
connect_ports(converter,one_port(converter),joint,named_port(joint,label));
end

function add_output(parent,joint,label,unit,variable)
converter = [parent '/FromPS_' label];
sink = [parent '/Log_' label];
add_block('nesl_utility/PS-Simulink Converter',converter,'Unit',unit);
add_block('simulink/Sinks/To Workspace',sink,'VariableName',variable,'SaveFormat','Structure With Time');
connect_ports(joint,named_port(joint,label),converter,one_port(converter));
add_line(parent,['FromPS_' label '/1'],['Log_' label '/1']);
end

function name = one_port(block)
ports = simscape.connectionPortProperties(block);
assert(numel(ports) == 1,'Expected one physical connection port');
name = ports(1).Name;
end

function name = named_port(block,label)
ports = simscape.connectionPortProperties(block);
matches = false(size(ports));
for k = 1:numel(ports)
    matches(k) = strcmp(ports(k).Name,label) || strcmp(ports(k).Label,label);
end
assert(nnz(matches) == 1,['Physical port absent or ambiguous: ' label]);
name = ports(matches).Name;
end

function connect_ports(first,firstPort,second,secondPort)
simscape.addConnection(first,firstPort,second,secondPort,'autorouting','off');
end

function value = first_sample(result,name,width)
value = readProbeInitialSample(result.get(name),width);
end

function value = unit_wrench(index)
value = zeros(6,1);
value(index) = 1;
end

function close_owned(model)
if bdIsLoaded(model)
    close_system(model,0);
end
end

function restore_settings(originalPath,originalDirectory,originalVisible)
cd(originalDirectory);
set(groot,'DefaultFigureVisible',originalVisible);
path(originalPath);
end

function bytes = read_bytes(file)
fid = fopen(file,'rb');
assert(fid ~= -1,'Cannot read immutable source library');
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid,Inf,'*uint8');
end

function write_tetrahedron(file)
vertices = [0 0 0;1 0 0;0 1 0;0 0 1];
faces = [1 3 2;1 2 4;1 4 3;2 3 4];
fid = fopen(file,'w');
assert(fid ~= -1,'Cannot create owned geometry fixture');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'solid fixture\n');
for row = faces'
    triangle = vertices(row,:);
    normal = cross(triangle(2,:)-triangle(1,:),triangle(3,:)-triangle(1,:));
    normal = normal/norm(normal);
    fprintf(fid,'facet normal %.17g %.17g %.17g\nouter loop\n',normal);
    fprintf(fid,'vertex %.17g %.17g %.17g\n',triangle');
    fprintf(fid,'endloop\nendfacet\n');
end
fprintf(fid,'endsolid fixture\n');
end
