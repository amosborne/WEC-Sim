function force = probeFullDirectionalSpectralBus(body,waves,time,forkRoot)
% Copy the actual native FullDir signal subsystem; no body dynamics or force table.
[~,token] = fileparts(tempname);
model = ['spectral_' token];
library = 'WECSim_Lib_Body_Elements';
libraryWasLoaded = bdIsLoaded(library);
names = {'body','Nwave','nativeSpectralHydro','nativeSpectralFextType','nativeSpectralHydroType'};
state = capture_base(names);
cleanup = onCleanup(@() restore_fixture(model,library,libraryWasLoaded,state));
assignin('base','body',body);
assignin('base','Nwave',waves);
fields = {'dofGrd','dirGrd','wGrd','qDofGrd','qWGrd','fEHRE','fEHIM','fEHMD'};
native = body.hydroForce.hf1.fExt;
selected = struct;
for k = 1:numel(fields)
    selected.(fields{k}) = native.(fields{k});
    elements(k) = Simulink.BusElement;
    elements(k).Name = fields{k};
    elements(k).Dimensions = size(selected.(fields{k}));
    elements(k).DataType = 'double';
end
fextType = Simulink.Bus;
fextType.Elements = elements;
rootElement = Simulink.BusElement;
rootElement.Name = 'fExt';
rootElement.DataType = 'Bus: nativeSpectralFextType';
hydroType = Simulink.Bus;
hydroType.Elements = rootElement;
assignin('base','nativeSpectralFextType',fextType);
assignin('base','nativeSpectralHydroType',hydroType);
assignin('base','nativeSpectralHydro',struct('fExt',selected));
libraryPath = fullfile(forkRoot,'source','lib','WEC-Sim',[library '.slx']);
load_system(libraryPath);
[~,expected] = fileattrib(libraryPath);
[~,actual] = fileattrib(get_param(library,'FileName'));
assert(strcmpi(actual.Name,expected.Name),'Wrong source library loaded.');
source = [library '/Rigid Body/Hydrodynamic Body/' ...
    'Wave Diffraction and Excitation Force Calculation/' ...
    'Linear Wave Excitation Force Variant Subsystem/Irregular Wave Full Direction'];
new_system(model);
add_block(source,[model '/Native FullDir']);
add_block('simulink/Sources/Clock',[model '/Time']);
add_block('simulink/Sources/Constant',[model '/Zero displacement'],'Value','zeros(1,6)');
add_block('simulink/Sources/Constant',[model '/Native coefficients'], ...
    'Value','nativeSpectralHydro','OutDataTypeStr','Bus: nativeSpectralHydroType');
add_block('simulink/Sinks/To Workspace',[model '/Applied force'], ...
    'VariableName','nativeSpectralForce','SaveFormat','Structure With Time');
add_line(model,'Time/1','Native FullDir/1');
add_line(model,'Zero displacement/1','Native FullDir/2');
add_line(model,'Native coefficients/1','Native FullDir/3');
add_line(model,'Native FullDir/1','Applied force/1');
set_param(model,'Solver','ode4','FixedStep',num2str(time(2)-time(1),17), ...
    'StartTime',num2str(time(1),17),'StopTime',num2str(time(end),17), ...
    'ReturnWorkspaceOutputs','on');
output = sim(model);
data = output.get('nativeSpectralForce');
assert(isequal(data.time(:),time(:)),'Native bus clock differs.');
values = data.signals.values;
if size(values,1) == numel(time) && numel(values) == 6*numel(time)
    force = reshape(values,numel(time),6);
elseif size(values,ndims(values)) == numel(time) && numel(values) == 6*numel(time)
    force = reshape(permute(values,[ndims(values) 1:ndims(values)-1]),numel(time),6);
else
    error('Unsupported native six-channel log layout.');
end
assert(isreal(force) && all(isfinite(force),'all'),'Native bus force is invalid.');
restore_fixture(model,library,libraryWasLoaded,state);
clear cleanup
end

function state = capture_base(names)
state = struct('name',names,'present',false,'value',[]);
for k = 1:numel(names)
    state(k).present = evalin('base',sprintf('exist(''%s'',''var'')',names{k})) ~= 0;
    if state(k).present
        state(k).value = evalin('base',names{k});
    end
end
end

function restore_fixture(model,library,libraryWasLoaded,state)
if bdIsLoaded(model)
    close_system(model,0);
end
if ~libraryWasLoaded && bdIsLoaded(library)
    close_system(library,0);
end
for k = 1:numel(state)
    if state(k).present
        assignin('base',state(k).name,state(k).value);
    else
        evalin('base',['clear ' state(k).name]);
    end
end
end
