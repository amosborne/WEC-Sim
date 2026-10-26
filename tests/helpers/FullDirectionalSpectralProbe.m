classdef FullDirectionalSpectralProbe < bodyClass
    methods
        function obj = FullDirectionalSpectralProbe(hydro)
            obj@bodyClass(hydro);
            obj.loadHydroData(hydro,1);
        end

        function prepare(obj,waves,rho,g)
            obj.irrExcitation(waves.omega,waves.bem.count,waves.direction, ...
                rho,g,waves.fullDirectionalSpectrum.directions,1);
        end

        function force = evaluate(obj,waves,times)
            h = obj.hydroForce.hf1.fExt;
            directions = waves.fullDirectionalSpectrum.directions;
            nDirection = numel(directions);
            nFrequency = numel(waves.omega);
            force = zeros(numel(times),6);
            for k = 1:numel(times)
                force(k,:) = irregExcFullDirF(0,waves.amplitude,waves.omega, ...
                    h.dofGrd,h.dirGrd,h.wGrd,h.qDofGrd,h.qWGrd, ...
                    h.fEHRE,h.fEHIM,h.fEHMD,waves.phase,waves.dOmega,times(k), ...
                    directions,zeros(1,6),obj.yaw.threshold,zeros(size(directions)), ...
                    zeros(nDirection,nFrequency,6),zeros(nDirection,nFrequency,6), ...
                    zeros(nDirection,nFrequency,6));
            end
        end
    end
end
