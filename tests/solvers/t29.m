% Test newton_system: max-iteration exhaustion is reported through flag=1.
% Companion to the univariate guard in t28: a single iteration on a
% nonlinear system cannot reach the tight tolerance, so the solver must
% return the best (non-converged) iterate with flag=1, never report
% convergence.

residual = @(v) [v(1)^2 - 2; v(2)^2 - 3];
jacobian = @(v) [2*v(1) 0; 0 2*v(2)];

[x, fval, iter, flag] = solvers.newton_system(residual, jacobian, [1.0; 1.0], 1e-12, 1);

if flag ~= 1
    error('Expected flag=1 (max iterations), got %d', flag)
end
if norm(fval, inf) < 1e-12
    error('residual should still be above tol after a single iteration')
end
if ~all(isfinite(x)) || ~all(isfinite(fval))
    error('best iterate and residual must remain finite')
end
