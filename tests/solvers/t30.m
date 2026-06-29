% Test modBuilder.solve: a non-converged Newton solve raises a contextual
% error and leaves the symbol value untouched (no silent wrong answer).
addpath ../utils
m = modBuilder();
m.add('y', 'y = k^alpha');
m.parameter('alpha', 0.36);
m.exogenous('k', 10);
m.endogenous('y', 1);

% Force non-convergence with a single Newton iteration at a tight tolerance.
threw = false;
try
    m.solve('y', 'y', 1.0, 1e-14, 1);
catch e
    threw = true;
    if ~strcmp(e.identifier, 'modBuilder:solve:noConvergence')
        error('Expected modBuilder:solve:noConvergence, got %s', e.identifier)
    end
end
assert(threw, 'solve should raise on non-convergence');

% The failed solve must not have assigned a value: the initial guess stands.
assert(m.y == 1, 'solve must not assign a value when it fails to converge (got %g)', m.y);

% A subsequent well-posed solve still works.
m.solve('y', 'y', 1.0);
assert(abs(m.y - 10^0.36) < 1e-8, 'solve should find y = 10^0.36 once allowed to converge');
