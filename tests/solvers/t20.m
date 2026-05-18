% Test newton_system: singular Jacobian must be detected.
% J is rank-deficient (second row is twice the first).

residual = @(v) [v(1) + v(2) - 1; 2*v(1) + 2*v(2) - 3];
jacobian = @(v) [1 1; 2 2];

threw = false;
try
    [x, fval, iter, flag] = solvers.newton_system(residual, jacobian, [0.5; 0.5], 1e-6, 20);
catch e
    threw = true;
    if ~strcmp(e.identifier, 'modBuilder:newtonSystem:singularJacobian')
        error('Expected modBuilder:newtonSystem:singularJacobian, got %s', e.identifier)
    end
end

if ~threw
    error('newton_system should have thrown on singular Jacobian')
end
