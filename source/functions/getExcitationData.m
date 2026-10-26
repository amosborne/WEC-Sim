function data = getExcitationData(hydro,waveType)
% Optional excitation-only coefficient view; raw hydro/radiation is never edited.
excitation = hydro.hydro_coeffs.excitation;
data = struct('w',hydro.simulation_parameters.w, ...
    'direction',hydro.simulation_parameters.direction, ...
    're',excitation.re,'im',excitation.im, ...
    'mean_drift',hydro.hydro_coeffs.mean_drift,'uses_component_view',false);
if ~isfield(excitation,'component_view')
    return
end
if ~strcmp(waveType,'spectrumImportFullDir')
    error('WECsim:UnsupportedExcitationView','Excitation component views require spectrumImportFullDir.');
end
view = excitation.component_view;
required = {'omega_rad_s','headings_deg','re','im','md'};
if ~isstruct(view) || ~isscalar(view) || ~all(isfield(view,required))
    error('WECsim:InvalidExcitationView','Excitation component view is incomplete.');
end
w = view.omega_rad_s;
theta = view.headings_deg;
if ~isnumeric(w) || ~isreal(w) || ~isvector(w) || numel(w) < 2 || ...
        any(~isfinite(w)) || any(diff(w(:)) <= 0) || any(w < 0) || ...
        ~isnumeric(theta) || ~isreal(theta) || ~isvector(theta) || numel(theta) < 2 || ...
        any(~isfinite(theta)) || any(diff(theta(:)) <= 0) || theta(1) ~= -180 || theta(end) ~= 180
    error('WECsim:InvalidExcitationView','Excitation view needs increasing finite frequency and full periodic heading axes.');
end
nDOF = size(excitation.re,1);
shape = [nDOF numel(theta) numel(w)];
for name = {'re','im','md'}
    value = view.(name{1});
    if ~isnumeric(value) || ~isreal(value) || ~isequal(size(value),shape) || any(~isfinite(value),'all')
        error('WECsim:InvalidExcitationView','Excitation view arrays must be finite real DOF-by-heading-by-frequency data.');
    end
    if ~isequal(value(:,1,:),value(:,end,:))
        error('WECsim:InvalidExcitationView','Excitation view periodic heading endpoints differ.');
    end
end
if any(view.md ~= 0,'all') || any(hydro.hydro_coeffs.mean_drift ~= 0,'all')
    error('WECsim:UnsupportedExcitationView','Excitation component views currently require zero mean drift.');
end
data.w = w(:)';
data.direction = theta(:)';
data.re = view.re;
data.im = view.im;
data.mean_drift = view.md;
data.uses_component_view = true;
end
