% Test newton_system on an arbitrarily large sparse system
% The system is: x_i - sum_j(A(i,j)*sin(x_j)) = b_i
% where A is a random sparse matrix and b is chosen so that x* = ones(n,1) is the solution.

n = 50;          % system size (controllable)
density = 0.15;  % fraction of non-zero entries (controllable)

rng(42);  % reproducibility
A = sprand(n, n, density);

% Target solution
xstar = ones(n, 1);

% Compute b so that xstar is the exact solution
b = xstar - A * sin(xstar);

% Residual: r_i = x_i - sum_j A(i,j)*sin(x_j) - b_i
residual_fn = @(x) x - A * sin(x) - b;

% Jacobian: J = I - A * diag(cos(x))
jacobian_fn = @(x) speye(n) - A * spdiags(cos(x), 0, n, n);

x0 = xstar + 0.5 * randn(n, 1);  % perturbed initial guess

[x, fval, iter] = solvers.newton_system(residual_fn, jacobian_fn, x0, 1e-10, 200);

if norm(fval) > 1e-8
    error('newton_system did not converge on %dx%d system (density=%.0f%%)', n, n, 100*density)
end

if norm(x - xstar) > 1e-6
    error('newton_system converged to wrong solution')
end

fprintf('t10.m: %dx%d system (%.0f%% dense), converged in %d iterations\n', n, n, 100*density, iter);
