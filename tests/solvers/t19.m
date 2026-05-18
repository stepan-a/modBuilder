% Test newton: 4-output call returns (x, fval, iter, flag), flag=0 on success.
% Also exercises 'arguments' validation by requiring scalar finite x0.

f = @(x) x^2 - 2;     % positive root sqrt(2) ≈ 1.4142135...

[x, fval, iter, flag] = solvers.newton(f, 1.0, 1e-10, 100);

if flag ~= 0
    error('expected flag=0 on convergence, got %d', flag)
end
if abs(fval) > 1e-10
    error('residual not converged, fval=%g', fval)
end
if abs(x - sqrt(2)) > 1e-8
    error('wrong root: got %g, expected %g', x, sqrt(2))
end
if iter < 1 || iter > 100
    error('iter out of range: %d', iter)
end

% Validation: non-scalar x0 must be rejected at the arguments block.
threw = false;
try
    solvers.newton(f, [1.0; 2.0]);
catch e
    threw = true;
end
if ~threw
    error('newton should reject non-scalar x0')
end
