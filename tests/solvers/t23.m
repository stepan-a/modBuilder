% Test newton_system: 4-output call returns (x, fval, iter, flag), flag=0
% on success, plus arguments-block validation.

residual = @(v) [v(1)^2 + v(2) - 3; v(1)*v(2) - 2];
jacobian = @(v) [2*v(1), 1; v(2), v(1)];

[x, fval, iter, flag] = solvers.newton_system(residual, jacobian, [0.5; 1.5], 1e-10, 100);

if flag ~= 0
    error('expected flag=0 on convergence, got %d', flag)
end
if norm(fval, inf) > 1e-10
    error('residual not converged, ||fval||_inf = %g', norm(fval, inf))
end
if iter < 1 || iter > 100
    error('iter out of range: %d', iter)
end
if abs(x(1) - 1) > 1e-6 || abs(x(2) - 2) > 1e-6
    error('wrong root: got [%g; %g], expected [1; 2]', x(1), x(2))
end

% Validation: non-finite x0 must be rejected by the arguments block.
threw = false;
try
    solvers.newton_system(residual, jacobian, [NaN; 1.5]);
catch
    threw = true;
end
if ~threw
    error('newton_system should reject NaN in x0')
end
