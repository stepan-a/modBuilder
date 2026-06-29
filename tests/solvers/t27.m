% Tests for newton_system() error paths. Every numerical failure is
% reported through flag (never thrown); only malformed inputs throw.

% Non-finite residual: residual_fn = 1/x at x0 = 0 is infinite on the first
% iterate.
[x, fval, iter, flag] = solvers.newton_system(@(x) 1./x, @(x) -1./x.^2, 0, 1e-6, 50);
assert(flag == 2, 'Expected flag=2 (non-finite residual) for an infinite residual, got %d', flag);

% Non-finite Jacobian: residual is finite at x0 = 0 but the Jacobian 1/x is
% infinite there.
[x, fval, iter, flag] = solvers.newton_system(@(x) x - 1, @(x) 1/x, 0, 1e-6, 50);
assert(flag == 2, 'Expected flag=2 (non-finite Jacobian) for an infinite Jacobian, got %d', flag);

% Line-search failure: a wrong-sign Jacobian makes the Newton step an ascent
% direction, so no backtracking step satisfies the Armijo condition and alpha
% underflows the floor.
[x, fval, iter, flag] = solvers.newton_system(@(x) x, @(x) -1, 1, 1e-6, 50);
assert(flag == 3, 'Expected flag=3 (line-search failure) when the step is not a descent direction, got %d', flag);
