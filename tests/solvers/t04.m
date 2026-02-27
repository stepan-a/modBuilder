% f(x,y) = [x^2 + y - 3; x*y - 2]  → solution near (1, 2)
residual = @(v) [v(1)^2 + v(2) - 3; v(1)*v(2) - 2];
jacobian = @(v) [2*v(1), 1; v(2), v(1)];
[x, fval, iter] = solvers.newton_system(residual, jacobian, [0.5; 1.5]);
if norm(fval) > 1e-6
    error('newton_system did not converge')
end
