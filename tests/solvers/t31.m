% Test modBuilder.solve_system: a non-converged Newton solve raises a
% contextual error and leaves every symbol value untouched.
addpath ../utils
m = modBuilder();
m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
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

% A subsequent well-posed solve still works.
m.solve_system({'y', 'c'}, {'y', 'c'});
ytrue = 10^0.36;
assert(abs(m.y - ytrue) < 1e-6 && abs(m.c - (ytrue - 0.25)) < 1e-6, ...
       'solve_system should find the steady state once allowed to converge');
