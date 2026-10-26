classdef ImportedExcitationGroupProbe < bodyClass
    methods
        function obj = ImportedExcitationGroupProbe(lags,kernel)
            h.properties = struct('centerGravity',[0 0 0],'centerBuoyancy',[0 0 0], ...
                'volume',1,'name','directional group fixture','dof',6,'dofStart',1,'dofEnd',6);
            h.simulation_parameters.direction = [0 90];
            h.simulation_parameters.w = [1 2];
            h.hydro_coeffs.linear_restoring_stiffness = zeros(6);
            h.hydro_coeffs.excitation.impulse_response_fun.t = lags;
            h.hydro_coeffs.excitation.impulse_response_fun.f = kernel;
            obj@bodyClass(h);
            obj.loadHydroData(h,1);
        end

        function force = prepare(obj,waves,dt)
            simu = simulationClass();
            simu.dt = dt;
            simu.rho = 1;
            simu.gravity = 1;
            simu.rampTime = 0;
            obj.hydroForcePre(waves,simu,1);
            force = obj.hydroForce.hf1.userDefinedFe;
        end
    end

    methods (Access = protected)
        function setMassMatrix(obj,varargin)
            % Isolate the excitation boundary from unrelated mass preparation.
        end

        function irfInfAddedMassAndDamping(obj,varargin)
            % No radiation or body dynamics occurs in this signal fixture.
        end
    end
end
