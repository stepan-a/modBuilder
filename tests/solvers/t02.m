f = @(x) x^3 - 3^x + 1;

[x, fval, iter] = solvers.newton(f, 1.6, 1e-6, 100);

if abs(fval)>1e-6
    error('Newton solver did not converge.')
end
