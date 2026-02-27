% Larger system to verify scaling
residual = @(v) [v(1) + v(2) + v(3) - 6; v(1)*v(2) - v(3) + 1; v(1)^2 - v(2) - 1];
jacobian = @(v) [1, 1, 1; v(2), v(1), -1; 2*v(1), -1, 0];
[x, fval, iter] = solvers.newton_system(residual, jacobian, [1; 1; 1]);
if norm(fval) > 1e-6
    error('newton_system did not converge on 3x3 system')
end
