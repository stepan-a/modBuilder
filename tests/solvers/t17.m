% Test newton: singular Jacobian (constant residual function).
% A constant f has zero derivative everywhere; the solver must report this
% through flag=2 (no value found), NOT silently return Inf/NaN and NOT throw.

f = @(x) x - x + 1;   % constant 1, but kept as autoDiff1 expression

[x, fval, iter, flag] = solvers.newton(f, 0, 1e-6, 50);

if flag ~= 2
    error('Expected flag=2 (singular Jacobian), got %d', flag)
end
if ~isfinite(fval)
    error('residual should remain finite, got %g', fval)
end
