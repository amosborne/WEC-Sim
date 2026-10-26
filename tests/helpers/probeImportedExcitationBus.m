function report = probeImportedExcitationBus(body,waves,time,library,folder,rewireControl)
% Simulate actual imported source + Add, using the native replication script.
% Unused variant inputs are zero/terminated; this is not a full body model.
if nargin < 6
    rewireControl = false;
end
[~,suffix] = fileparts(tempname(folder));
model = ['imported_bus_' suffix];
assert(~bdIsLoaded(model),'Owned signal-fixture name already exists');
savedBase = snapshot_base({'fixtureBody','waves','typeNum'});
cleanup = onCleanup(@() restore_fixture(model,savedBase));
new_system(model);
% Native WEC uses the base workspace; model workspaces reject waveClass arrays.
assignin('base','fixtureBody',body);
assignin('base','waves',waves);
assignin('base','typeNum',40);
source = [library '/Rigid Body/Hydrodynamic Body/Wave Diffraction and Excitation Force Calculation'];
parent = [model '/Excitation'];
add_block('built-in/Subsystem',parent);
baseName = 'Linear Wave Excitation Force Variant Subsystem';
base = [parent '/' baseName];
add_block('built-in/Subsystem',base);
mask = Simulink.Mask.create(base);
mask.addParameter('Type','edit','Name','Nwave','Value','waves(1)','Evaluate','on');
for j = 1:3
    add_block('simulink/Ports & Subsystems/In1',[base '/Unused' num2str(j)],'Port',num2str(j));
    add_block('simulink/Sinks/Terminator',[base '/Terminate' num2str(j)]);
    add_line(base,['Unused' num2str(j) '/1'],['Terminate' num2str(j) '/1']);
end
choice = [source '/' baseName '/' sprintf('User Defined Wave \nExcitation Force')];
add_block(choice,[base '/Native imported source']);
actual = get_param([base '/Native imported source/InputWaveForceTimeHistory1'],'VariableName');
assert(strcmp(actual,'[Nwave.waveAmpTime(:,1),body.hydroForce.hf1.userDefinedFe]'), ...
    'Native imported source binding changed');
add_block('simulink/Ports & Subsystems/Out1',[base '/Output']);
add_line(base,'Native imported source/1','Output/1');
add_block('built-in/Subsystem',[parent '/FexcInputs']);
for j = 1:4
    add_block('simulink/Sources/Constant',[parent '/FexcInputs/Zero' num2str(j)],'Value','0');
    add_block('simulink/Ports & Subsystems/Out1',[parent '/FexcInputs/Out' num2str(j)],'Port',num2str(j));
    add_line([parent '/FexcInputs'],['Zero' num2str(j) '/1'],['Out' num2str(j) '/1']);
end
for j = 1:3
    ports = [1 2 4];
    add_line(parent,['FexcInputs/' num2str(ports(j))],[baseName '/' num2str(j)]);
end
add_block([source '/Add'],[parent '/Add']);
add_line(parent,[baseName '/1'],'Add/1');
for j = 2:3
    add_block('simulink/Sources/Constant',[parent '/Unused force ' num2str(j)],'Value','zeros(1,6)');
    add_line(parent,['Unused force ' num2str(j) '/1'],['Add/' num2str(j)]);
end
add_block('simulink/Ports & Subsystems/Out1',[parent '/Output']);
add_line(parent,'Add/1','Output/1');
mask = Simulink.Mask.create(parent);
mask.addParameter('Type','edit','Name','body','Value','fixtureBody','Evaluate','on');
mask.addParameter('Type','edit','Name','waveGroup','Value','waves','Evaluate','on');
nativeMask = Simulink.Mask.get(source);
mask.Initialization = nativeMask.Initialization;
add_block('simulink/Sinks/To Workspace',[model '/Applied force'], ...
    'VariableName','appliedExcitation','SaveFormat','Structure With Time');
add_line(model,'Excitation/1','Applied force/1');
set_param(model,'Solver','ode4','FixedStep',num2str(time(2)-time(1),17), ...
    'StartTime',num2str(time(1),17),'StopTime',num2str(time(end),17),'ReturnWorkspaceOutputs','on');
set_param(model,'SimulationCommand','update');
freshCount = branch_count(parent,baseName);
% Exercise native branch reconciliation; this regular transition is GRAPH
% evidence only, not a regular-wave forcing simulation.
for j = 1:numel(waves)
    regular(j) = waveClass('regularCIC');
    regular(j).height = .02;
    regular(j).period = 4;
    regular(j).direction = 90*(j-1);
    regular(j).setup([1 2],inf,0,time(2)-time(1),numel(time)-1,time',1,1);
end
assignin('base','waves',regular);
set_param(parent,'waveGroup',sprintf('waves(1:%d)',numel(regular)));
set_param(model,'SimulationCommand','update');
regularCount = branch_count(parent,baseName);
customRejected = false;
if rewireControl
    clone = [parent '/' baseName '2'];
    delete_line(clone,'Unused1/1','Terminate1/1');
    delete_line(clone,'Unused2/1','Terminate2/1');
    add_line(clone,'Unused1/1','Terminate2/1');
    add_line(clone,'Unused2/1','Terminate1/1');
    try
        importedExcitationBranches(parent,waves);
    catch failure
        customRejected = strcmp(failure.identifier,'WECsim:ModifiedExcitationBranch') && ...
            contains(failure.message,'internal wiring differs');
    end
    assert(customRejected && getSimulinkBlockHandle(clone) ~= -1 && ...
        branch_count(parent,baseName) == regularCount, ...
        'Rewired clone was not rejected without deletion');
    delete_line(clone,'Unused1/1','Terminate2/1');
    delete_line(clone,'Unused2/1','Terminate1/1');
    add_line(clone,'Unused1/1','Terminate1/1');
    add_line(clone,'Unused2/1','Terminate2/1');
end
assignin('base','waves',waves);
set_param(parent,'waveGroup','waves');
set_param(model,'SimulationCommand','update');
restoredCount = branch_count(parent,baseName);
out = sim(model);
data = out.get('appliedExcitation');
assert(size(data.signals.values,1) == numel(time) && ...
    size(data.signals.values,2) == 6 && max(abs(data.time(:)-time(:))) < 1e-10, ...
    'Native imported bus sample grid or six-channel layout differs');
report = struct('time',data.time(:),'applied',data.signals.values, ...
    'branch_count',branch_count(parent,baseName),'fresh_count',freshCount, ...
    'regular_graph_count',regularCount,'restored_count',restoredCount,'native_expression',actual, ...
    'rewired_clone_rejected_without_deletion',customRejected, ...
    'scope','native imported source/Add and replication script; unused variant inputs zero, no body dynamics');
% Explicit restoration must succeed before reporting success; onCleanup retries
% the same idempotent restoration if an earlier operation failed.
restore_fixture(model,savedBase);
end

function count = branch_count(parent,baseName)
% RegExp applies to property filters too; discover canonical block handles
% literally, then apply the branch-name expression separately.
blocks = find_system(parent,'FindAll','on','SearchDepth',1, ...
    'LookUnderMasks','all','FollowLinks','on','MatchFilter',@Simulink.match.allVariants, ...
    'RegExp','off','Type','block');
children = [];
names = {};
paths = {};
for k = 1:numel(blocks)
    if strcmp(get_param(blocks(k),'Parent'),parent)
        children(end+1) = blocks(k);
        names{end+1} = get_param(blocks(k),'Name');
        paths{end+1} = getfullname(blocks(k));
    end
end
base = getSimulinkBlockHandle([parent '/' baseName]);
assert(base ~= -1 && any(children == base),'WECsim:FixtureBranchDiscovery', ...
    ['Known native base branch missing from literal child-block query. Parent=' ...
    parent '; discovered=' strjoin(paths,' | ')]);
pattern = ['^' regexptranslate('escape',baseName) '[0-9]*$'];
matched = ~cellfun(@isempty,regexp(names,pattern,'once'));
count = nnz(matched);
assert(count > 0,'WECsim:FixtureBranchDiscovery', ...
    ['No actual child branch names matched. Parent=' parent '; names=' ...
    strjoin(names,' | ') '; paths=' strjoin(paths,' | ')]);
end

function state = snapshot_base(names)
state = struct('name',{},'existed',{},'value',{});
for j = 1:numel(names)
    name = names{j};
    existed = evalin('base',['exist(''' name ''',''var'') == 1']);
    value = [];
    if existed
        value = evalin('base',name);
    end
    state(j) = struct('name',name,'existed',existed,'value',{value});
end
end

function restore_fixture(model,state)
failures = {};
try
    if bdIsLoaded(model)
        close_system(model,0);
    end
catch failure
    failures{end+1} = failure.message;
end
% Attempt every owned variable even if model close or another restore fails.
for j = 1:numel(state)
    name = state(j).name;
    try
        if state(j).existed
            assignin('base',name,state(j).value);
        else
            evalin('base',['clear(''' name ''')']);
        end
        existed = evalin('base',['exist(''' name ''',''var'') == 1']);
        assert(existed == state(j).existed,'Fixture variable existence was not restored');
        if existed
            assert(isequaln(evalin('base',name),state(j).value),'Fixture variable value was not restored');
        end
    catch failure
        failures{end+1} = [name ': ' failure.message];
    end
end
if ~isempty(failures)
    error('WECsim:ImportedFixtureCleanup','Owned fixture cleanup failed: %s',strjoin(failures,'; '));
end
end
