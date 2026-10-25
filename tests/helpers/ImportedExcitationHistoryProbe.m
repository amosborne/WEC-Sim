classdef ImportedExcitationHistoryProbe < bodyClass
    % Synthetic fixture for own-fork issue #1; production excitation is intact.
    methods
        function obj = ImportedExcitationHistoryProbe(lags,kernel)
            h.properties = struct('centerGravity',[0 0 0],'centerBuoyancy',[0 0 0], ...
                'volume',1,'name','history fixture','dof',6,'dofStart',1,'dofEnd',6);
            h.simulation_parameters.direction = 0;
            h.simulation_parameters.w = [1 2];
            h.hydro_coeffs.linear_restoring_stiffness = zeros(6);
            h.hydro_coeffs.excitation.impulse_response_fun.t = lags;
            h.hydro_coeffs.excitation.impulse_response_fun.f = reshape(kernel,6,1,[]);
            h.hydro_coeffs.excitation.re = repmat(reshape(1:6,6,1,1),1,1,2);
            h.hydro_coeffs.excitation.im = -2*h.hydro_coeffs.excitation.re;
            h.hydro_coeffs.mean_drift = 3*h.hydro_coeffs.excitation.re;
            obj@bodyClass(h);
            obj.loadHydroData(h,1);
        end

        function force = prepare(obj,waves,dt,rampTime)
            simu = simulationClass();
            simu.dt = dt;
            simu.rho = 1;
            simu.gravity = 1;
            simu.rampTime = rampTime;
            obj.hydroForcePre(waves,simu,1);
            force = obj.hydroForce.hf1.userDefinedFe;
        end

        function force = legacy(obj,table,dt)
            obj.userDefinedExcitation(table,dt,0,1,1,1);
            force = obj.hydroForce.hf1.userDefinedFe;
        end

        function force = raw(obj,table,dt,history,rampTime)
            obj.userDefinedExcitation(table,dt,0,1,1,1,history,rampTime);
            force = obj.hydroForce.hf1.userDefinedFe;
        end
    end

    methods (Access = protected)
        function setMassMatrix(obj,varargin)
            % Mass mapping is unrelated to this excitation-only fixture.
        end

        function irfInfAddedMassAndDamping(obj,varargin)
            % Radiation preparation is unrelated to this excitation fixture.
        end
    end
end
