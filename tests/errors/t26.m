% Tests for newton solver: default arguments and line-search damping

% Test 1: Default maxit and tol (2 args only)
f = @(x) x^2 - 4;
x = solvers.newton(f, 3.0);
assert(abs(x - 2.0) < 1e-6, 'Newton should find root with default tol and maxit.');

% Test 2: Default maxit (3 args)
x = solvers.newton(f, 3.0, 1e-8);
assert(abs(x - 2.0) < 1e-8, 'Newton should find root with default maxit.');

% Test 3: All args specified
x = solvers.newton(f, 3.0, 1e-10, 50);
assert(abs(x - 2.0) < 1e-10, 'Newton should find root with all args.');

% Test 4: Line-search damping
% Use a function where the full Newton step can overshoot:
%   f(x) = atan(x) has slow convergence from far away
%   because f'(x) = 1/(1+x^2), and Newton: x - atan(x)*(1+x^2)
%   can overshoot significantly for large x.
g = @(x) atan(x) - 1;
x = solvers.newton(g, 20.0, 1e-6, 200);
assert(abs(g(x)) < 1e-5, 'Newton with line-search should converge.');
