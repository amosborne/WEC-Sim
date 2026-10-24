function count = importedExcitationBranches(parent, waveGroup)
% Imported excitation is precomputed as a directional sum in bodyClass.
% Keep its total in one branch; retain native replication for other waves.
count = size(waveGroup,2);
imported = false(1,numel(waveGroup));
for i = 1:numel(waveGroup)
    imported(i) = strcmp(waveGroup(i).type,'elevationImport');
end
if ~any(imported)
    return
end
if ~all(imported)
    error('Cannot mix elevationImport and other wave types in one excitation group.');
end
count = 1;
% A previously regular multi-wave model may retain generated branches. Remove
% only native numbered clones, including their positive sum ports.
clones = find_system(parent,'SearchDepth',1,'LookUnderMasks','all','FollowLinks','on', ...
    'MatchFilter',@Simulink.match.allVariants,'regexp','on', ...
    'Name','^Linear Wave Excitation Force Variant Subsystem[0-9]+$');
removePorts = zeros(1,numel(clones));
lines = zeros(1,numel(clones));
sumBlock = [parent '/Add'];
signs = get_param(sumBlock,'Inputs');
for i = 1:numel(clones)
    assert(~isempty(regexp(get_param(clones{i},'Nwave'),'^waves\([0-9]+\)$','once')), ...
        'Unexpected numbered excitation branch; rebuild the model from its library.');
    ports = get_param(clones{i},'PortHandles');
    lines(i) = get_param(ports.Outport(1),'Line');
    assert(lines(i) ~= -1,'Generated excitation branch is not connected to its sum.');
    destination = get_param(lines(i),'DstPortHandle');
    assert(numel(destination) == 1 && strcmp(get_param(destination,'Parent'),sumBlock), ...
        'Generated excitation branch has unexpected output wiring.');
    removePorts(i) = get_param(destination,'PortNumber');
    assert(signs(removePorts(i)) == '+','Generated excitation sum sign must be positive.');
end
assert(numel(unique(removePorts)) == numel(removePorts));
for i = 1:numel(clones)
    delete_line(lines(i));
    delete_block(clones{i});
end
if ~isempty(removePorts)
    signs(sort(removePorts,'descend')) = [];
    set_param(sumBlock,'Inputs',signs);
end
end
