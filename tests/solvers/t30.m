% Test modBuilder.solve: a non-converged Newton solve raises a contextual
% error and leaves the symbol value untouched (no silent wrong answer).
addpath ../utils
m = modBuilder();
m.add('y', 'log(y) = alpha*log(k)');
m.parameter('alpha', 0.36);
m.exogenous('k', 10);
m.endogenous('y', 1);

% Force non-convergence with a single Newton iteration at a tight tolerance.
% The equation is nonlinear in y (log form), so one step cannot land on the
% root exactly -- a linear equation would, and the solver now correctly
% reports a last-iteration exact hit as convergence.
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

% A subsequent well-posed solve still works (tight tolerance: the residual is
% on the log scale, so the default 1e-6 would only pin y to ~2e-6).
m.solve('y', 'y', 1.0, 1e-12);
assert(abs(m.y - 10^0.36) < 1e-8, 'solve should find y = 10^0.36 once allowed to converge');
