f = @(x) exp(x)-1;

[x, fval, iter] = solvers.newton(f, 2, 1e-6, 100);

if abs(fval)>1e-6
    error('Newton solver did not converge.')
end
