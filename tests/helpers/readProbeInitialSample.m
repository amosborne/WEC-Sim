function value = readProbeInitialSample(log,width)
% Accept explicit Structure With Time layouts without blending time samples.
assert(isnumeric(log.time) && isvector(log.time) && ~isempty(log.time) && ...
    log.time(1) == 0,'Direct initial sample is unavailable');
assert(isscalar(log.signals) && isfield(log.signals,'dimensions'), ...
    'Signal dimensions must be declared');
dims = log.signals.dimensions;
assert(isnumeric(dims) && isvector(dims) && ~isempty(dims) && numel(dims) <= 2 && ...
    all(isfinite(dims)) && all(dims >= 1) && all(dims == fix(dims)), ...
    'Unsupported declared signal dimensions');
dims = double(dims(:)');
assert(prod(dims) == width,'Unexpected native sensor dimensions');
data = log.signals.values;
assert(isnumeric(data) && isreal(data) && ndims(data) <= 3, ...
    'Unsupported native sensor value array');
count = numel(log.time);
timeFirst = same_shape(size(data),[count dims]);
timeLast = numel(dims) == 2 && same_shape(size(data),[dims count]);
assert(timeFirst || timeLast,'Unsupported native sensor time-axis layout');
assert(~(timeFirst && timeLast && count > 1),'Ambiguous native sensor time-axis layout');
if timeFirst
    sample = data(1,:,:);
else
    sample = data(:,:,1);
end
assert(numel(sample) == width,'Initial sensor sample has unexpected width');
value = sample(:);
end

function match = same_shape(actual,expected)
count = max(numel(actual),numel(expected));
actual(end+1:count) = 1;
expected(end+1:count) = 1;
match = isequal(actual,expected);
end
