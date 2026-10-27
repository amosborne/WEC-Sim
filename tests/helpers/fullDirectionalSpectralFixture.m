function fixture = fullDirectionalSpectralFixture(folder,directions,includePhase)
% Integrated physical amplitudes, independent of WEC spectrum storage weights.
fixture.omega = [.4;.9;1.7];
fixture.dt = .125;
fixture.time = (0:fixture.dt:2)';
fixture.rho = 1025;
fixture.g = 9.81;
fixture.positions = [0 0;1.25 -.5];
directions = directions(:);
fixture.amplitudes = [.2 .11 .09;.07 .16 .04;.13 .05 .12];
fixture.phases = [.3 -.7 .4;1.1 .2 -1.3;-1.4 .9 1.7];
fixture.amplitudes = fixture.amplitudes(:,1:numel(directions));
fixture.phases = fixture.phases(:,1:numel(directions));
fixture.directions = directions;
frequencies = fixture.omega/(2*pi);
nativeOmega = frequencies*2*pi;
dw = [nativeOmega(2)-nativeOmega(1); ...
    (nativeOmega(3)-nativeOmega(1))/2;nativeOmega(3)-nativeOmega(2)];
width = direction_widths(directions);
energy = sum(fixture.amplitudes.^2,2);
spectrum = pi*energy./dw;
spread = fixture.amplitudes.^2./(energy*width);
phase = fixture.phases;
fixture.file = fullfile(folder,'full-directional-spectrum.mat');
if includePhase
    save(fixture.file,'frequencies','directions','spectrum','spread','phase');
else
    save(fixture.file,'frequencies','directions','spectrum','spread');
end
fixture.width = width;
h.properties = struct('centerGravity',[0 0 0],'centerBuoyancy',[0 0 0], ...
    'volume',1,'name','spectral fixture','dof',6,'dofStart',1,'dofEnd',6);
h.simulation_parameters.direction = [-180 -90 -60 0 60 90 180];
h.simulation_parameters.w = fixture.omega';
h.hydro_coeffs.linear_restoring_stiffness = zeros(6);
nativeTransfer = complex(zeros(6,7,3));
for frequency = 1:3
    for mode = 1:6
        for direction = 1:7
            theta = h.simulation_parameters.direction(direction);
            nativeTransfer(mode,direction,frequency) = ...
                (mode+.2*fixture.omega(frequency))*(1+.25*cosd(theta)) ...
                +1i*(.05*mode^2+.1*fixture.omega(frequency))*(.5+.25*sind(theta));
        end
    end
end
[present,indices] = ismember(directions,h.simulation_parameters.direction);
assert(all(present),'Fixture directions must be exact coefficient nodes.');
fixture.transfer = permute(nativeTransfer(:,indices,:),[3 2 1]);
coefficients = nativeTransfer/(fixture.rho*fixture.g);
h.hydro_coeffs.excitation.re = real(coefficients);
h.hydro_coeffs.excitation.im = -imag(coefficients);
h.hydro_coeffs.mean_drift = zeros(size(coefficients));
fixture.hydro = h;
end

function width = direction_widths(directions)
% Independent storage preparation using the documented native bin rule.
width = zeros(1,numel(directions));
width(1) = deg2rad(directions(2)-directions(1));
for k = 2:numel(directions)-1
    width(k) = deg2rad((directions(k+1)-directions(k-1))/2);
end
width(end) = deg2rad(directions(end)-directions(end-1));
end
