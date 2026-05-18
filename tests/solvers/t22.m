% Test newton_system: residual reuse across iterations.
% Pre-patch the solver computed residual_fn(x) once at the top of every
% outer iteration AND once per line-search trial (so ~2*iter calls). The
% patched solver:
%   - calls residual_fn once before the loop (initial fx),
%   - reuses the accepted line-search residual as the next iteration's fx,
%   - tests convergence at the top of each iteration (no call there).
% For a well-conditioned problem where alpha=1 is always accepted, this
% gives exactly `iter` total residual evaluations.

state = containers.Map('KeyType', 'char', 'ValueType', 'double');
state('calls') = 0;

residual = @(v) tcount(state, v);
jacobian = @(v) [2*v(1), 1; v(2), v(1)];

[x, fval, iter, flag] = solvers.newton_system(residual, jacobian, [0.5; 1.5], 1e-10, 50);

calls = state('calls');

if flag ~= 0
    error('expected convergence (flag=0), got %d', flag)
end

% Strict reuse expectation. Pre-patch this would have been ~2*iter.
% Allow at most one extra evaluation to absorb a single backtrack.
if calls > iter + 1
    error('residual reuse regressed: %d calls for %d iterations (expected ~%d)', ...
          calls, iter, iter)
end
if calls < iter
    error('unexpectedly few residual calls (%d for %d iterations)', calls, iter)
end

function r = tcount(state, v)
    state('calls') = state('calls') + 1;
    r = [v(1)^2 + v(2) - 3; v(1)*v(2) - 2];
end
