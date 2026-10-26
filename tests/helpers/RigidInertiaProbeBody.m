classdef RigidInertiaProbeBody < bodyClass
    % Expose unchanged production adjustment using synthetic coefficients.
    methods
        function obj = RigidInertiaProbeBody(M,A)
            h.properties = struct('centerGravity',[0 0 0],'centerBuoyancy',[0 0 0], ...
                'volume',1,'name','rigid inertia probe','dof',6,'dofStart',1,'dofEnd',6);
            h.simulation_parameters.w = [1 2];
            h.hydro_coeffs.added_mass.all = repmat(A,1,1,2);
            h.hydro_coeffs.radiation_damping.all = zeros(6,6,2);
            obj@bodyClass(h);
            obj.loadHydroData(h,1);
            obj.mass = M(1,1);
            obj.inertia = diag(M(4:6,4:6))';
            obj.inertiaProducts = [M(4,5) M(4,6) M(5,6)];
            obj.constAddedMassAndDamping(1,1,0,1);
            obj.adjustMassMatrix(0,1);
        end
    end
end
