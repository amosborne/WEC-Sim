function count = importedExcitationBranches(parent,waveGroup)
% One native branch consumes bodyClass's summed imported excitation.
count = size(waveGroup,2);
assert(count >= 1,'WECsim:EmptyWaveGroup','Wave group must not be empty');
imported = arrayfun(@(wave) strcmp(wave.type,'elevationImport'),waveGroup);
if any(imported) && ~all(imported)
    error('WECsim:MixedImportedExcitation','All Wave-Spectra should be the same type as waves(1).');
end
if all(imported)
    count = 1;
end
baseName = 'Linear Wave Excitation Force Variant Subsystem';
base = [parent '/' baseName];
sumBlock = [parent '/Add'];
clones = find_system(parent,'SearchDepth',1,'LookUnderMasks','all','FollowLinks','on', ...
    'MatchFilter',@Simulink.match.allVariants,'regexp','on','Name',['^' baseName '[0-9]+$']);
remove = {};
removePorts = [];
lines = [];
signs = get_param(sumBlock,'Inputs');
for k = 1:numel(clones)
    name = get_param(clones{k},'Name');
    index = str2double(erase(name,baseName));
    if index <= count
        continue
    end
    assert(index >= 2 && strcmp(get_param(clones{k},'Nwave'),sprintf('waves(%d)',index)), ...
        'WECsim:ModifiedExcitationBranch','Numbered excitation branch has unexpected wave ownership');
    assert(strcmp(get_param(clones{k},'BlockType'),get_param(base,'BlockType')) && ...
        strcmp(get_param(clones{k},'MaskInitialization'),get_param(base,'MaskInitialization')), ...
        'WECsim:ModifiedExcitationBranch','Numbered excitation branch differs from its native source');
    verify_native_clone(base,clones{k});
    ports = get_param(clones{k},'PortHandles');
    assert(numel(ports.Outport) == 1 && numel(ports.Inport) == 3, ...
        'WECsim:ModifiedExcitationBranch','Numbered excitation branch has unexpected ports');
    sources = get_param([parent '/FexcInputs'],'PortHandles');
    expected = sources.Outport([1 2 4]);
    for j = 1:3
        line = get_param(ports.Inport(j),'Line');
        assert(line ~= -1 && get_param(line,'SrcPortHandle') == expected(j), ...
            'WECsim:ModifiedExcitationBranch','Numbered excitation branch has custom input wiring');
    end
    line = get_param(ports.Outport(1),'Line');
    assert(line ~= -1,'WECsim:ModifiedExcitationBranch','Numbered excitation output is disconnected');
    destination = get_param(line,'DstPortHandle');
    assert(numel(destination) == 1 && strcmp(get_param(destination,'Parent'),sumBlock), ...
        'WECsim:ModifiedExcitationBranch','Numbered excitation output has custom wiring');
    port = get_param(destination,'PortNumber');
    assert(signs(port) == '+','WECsim:ModifiedExcitationBranch','Numbered excitation sign is not positive');
    remove{end+1} = clones{k};
    removePorts(end+1) = port;
    lines(end+1) = line;
end
assert(numel(unique(removePorts)) == numel(removePorts), ...
    'WECsim:ModifiedExcitationBranch','Numbered excitation outputs share a sum port');
% Validate the complete deletion set before mutating any branch or sum input.
for k = 1:numel(remove)
    delete_line(lines(k));
    delete_block(remove{k});
end
if ~isempty(removePorts)
    signs(sort(removePorts,'descend')) = [];
    set_param(sumBlock,'Inputs',signs);
end
end

function verify_native_clone(base,clone)
original = find_system(base,'LookUnderMasks','all','FollowLinks','on', ...
    'MatchFilter',@Simulink.match.allVariants,'Type','Block');
copied = find_system(clone,'LookUnderMasks','all','FollowLinks','on', ...
    'MatchFilter',@Simulink.match.allVariants,'Type','Block');
originalNames = erase(string(original),string(base));
copiedNames = erase(string(copied),string(clone));
assert(isequal(sort(originalNames),sort(copiedNames)), ...
    'WECsim:ModifiedExcitationBranch','Numbered excitation branch contains custom blocks');
for k = 1:numel(original)
    target = [clone char(originalNames(k))];
    assert(strcmp(get_param(original{k},'BlockType'),get_param(target,'BlockType')), ...
        'WECsim:ModifiedExcitationBranch','Numbered excitation block type differs');
    dialog = get_param(original{k},'DialogParameters');
    if isempty(dialog)
        continue
    end
    parameters = fieldnames(dialog);
    for j = 1:numel(parameters)
        name = parameters{j};
        if strcmp(original{k},base) && strcmp(name,'Nwave')
            continue
        end
        assert(isequal(get_param(original{k},name),get_param(target,name)), ...
            'WECsim:ModifiedExcitationBranch','Numbered excitation block parameters differ');
    end
end
assert(isequal(internal_connections(base),internal_connections(clone)), ...
    'WECsim:ModifiedExcitationBranch','Numbered excitation branch internal wiring differs');
end

function edges = internal_connections(root)
blocks = find_system(root,'LookUnderMasks','all','FollowLinks','on', ...
    'MatchFilter',@Simulink.match.allVariants,'Type','Block');
edges = {};
for k = 1:numel(blocks)
    if strcmp(blocks{k},root)
        continue
    end
    ports = get_param(blocks{k},'PortHandles');
    assert(isempty(ports.LConn) && isempty(ports.RConn), ...
        'WECsim:ModifiedExcitationBranch','Cannot prove clone ownership with physical connection ports');
    for j = 1:numel(ports.Outport)
        line = get_param(ports.Outport(j),'Line');
        if line == -1
            continue
        end
        destinations = get_param(line,'DstPortHandle');
        assert(all(destinations ~= -1), ...
            'WECsim:ModifiedExcitationBranch','Cannot prove ownership of a dangling internal line');
        for destination = destinations(:)'
            target = get_param(destination,'Parent');
            assert(startsWith(target,[root '/']), ...
                'WECsim:ModifiedExcitationBranch','Internal line leaves its excitation branch');
            edge = {erase(blocks{k},root),j,erase(target,root), ...
                get_param(destination,'PortType'),get_param(destination,'PortNumber')};
            edges{end+1} = jsonencode(edge);
        end
    end
end
edges = sort(edges);
end
