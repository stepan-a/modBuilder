% Test newton: singular Jacobian (constant residual function).
% A constant f has zero derivative everywhere; the solver must detect
% this and raise modBuilder:newton:singularJacobian, NOT silently
% return Inf/NaN.

f = @(x) x - x + 1;   % constant 1, but kept as autoDiff1 expression

threw = false;
try
    [x, fval, iter, flag] = solvers.newton(f, 0, 1e-6, 50);
catch e
    threw = true;
    if ~strcmp(e.identifier, 'modBuilder:newton:singularJacobian')
        error('Expected error id modBuilder:newton:singularJacobian, got %s', e.identifier)
    end
end

if ~threw
    error('newton should have thrown on singular Jacobian')
end
