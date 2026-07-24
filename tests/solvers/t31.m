% Test modBuilder.solve_system: a non-converged Newton solve raises a
% contextual error and leaves every symbol value untouched.
addpath ../utils
m = modBuilder();
m.add('y', 'y = k^alpha');
% Log form: same root (c = y - delta*k) but nonlinear in c, so a single Newton
% iteration cannot land on it exactly -- the linear form would, and the solver
% now correctly reports a last-iteration exact hit as convergence.
m.add('c', 'log(c) = log(y - delta*k)');
m.parameter('alpha', 0.36);
m.parameter('delta', 0.025);
m.exogenous('k', 10);
m.endogenous('y', 1);
m.endogenous('c', 1);

% Force non-convergence with a single Newton iteration at a tight tolerance.
threw = false;
try
    m.solve_system({'y', 'c'}, {'y', 'c'}, tol=1e-14, maxit=1);
catch e
    threw = true;
    if ~strcmp(e.identifier, 'modBuilder:solve_system:noConvergence')
        error('Expected modBuilder:solve_system:noConvergence, got %s', e.identifier)
    end
end
assert(threw, 'solve_system should raise on non-convergence');

% The failed solve must not have assigned values: the initial guesses stand.
assert(m.y == 1 && m.c == 1, ...
       'solve_system must not assign values when it fails to converge (got y=%g, c=%g)', m.y, m.c);

% A subsequent well-posed solve still works (tight tolerance: the c-residual is
% on the log scale, so the default 1e-6 would only pin c to ~2e-6).
m.solve_system({'y', 'c'}, {'y', 'c'}, tol=1e-10);
ytrue = 10^0.36;
assert(abs(m.y - ytrue) < 1e-6 && abs(m.c - (ytrue - 0.25)) < 1e-6, ...
       'solve_system should find the steady state once allowed to converge');
