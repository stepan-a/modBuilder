% Test newton: convergence is residual-based, not step-based.
% Adversarial residual: constant value 1 with a huge "derivative". The
% pre-patch solver terminated on |dx| < tol alone and would have returned
% fval = 1 as if converged. The patched solver tests |f(x)| < tol at the
% top of each iteration; for this adversarial setup the residual stays
% at 1, so the line search ultimately fails (no descent possible) and an
% error is raised — what matters is that the solver does NOT silently
% report convergence with a non-zero residual.

f = @(x) autoDiff1(1.0, 1e15);

threw       = false;
flag_value  = NaN;
fval_value  = NaN;
try
    [x, fval, iter, flag] = solvers.newton(f, 0, 1e-6, 5);
    flag_value = flag;
    fval_value = fval;
catch e
    threw = true;
    if ~startsWith(e.identifier, 'modBuilder:newton:')
        error('Expected modBuilder:newton:* error, got %s', e.identifier)
    end
end

if ~threw
    if flag_value == 0
        error('newton wrongly reported convergence with |fval|=%g (regression of dx-only termination bug)', ...
              abs(fval_value))
    end
    if abs(fval_value) < 1e-6
        error('residual is supposed to remain ~1 in this adversarial setup')
    end
end
