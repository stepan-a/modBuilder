% Test newton: max-iteration exhaustion is reported through flag=1.
% This guards the silent-failure bug: with too few iterations the solver
% must NOT report convergence — it returns the best (non-converged) iterate
% with flag=1 and a residual still above tol.

f = @(x) x^2 - 2;     % root sqrt(2); from x0=1 one step is not enough at 1e-12

[x, fval, iter, flag] = solvers.newton(f, 1.0, 1e-12, 1);

if flag ~= 1
    error('Expected flag=1 (max iterations), got %d', flag)
end
if abs(fval) < 1e-12
    error('residual should still be above tol after a single iteration, got %g', fval)
end
if ~isfinite(x) || ~isfinite(fval)
    error('best iterate and residual must remain finite')
end
if iter ~= 1
    error('expected iter=1, got %d', iter)
end
