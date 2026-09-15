% modBuilder.solve works on the simplified static equation.
addpath ../utils

% A symbol that cancels from the static equation needs no value: c/c(+1) is one at the
% steady state, so the Euler equation gives k with c still undefined.
m = modBuilder();
m.add('c', 'c = k^alpha - delta*k');
m.add('k', '1/beta = c/c(+1)*(alpha*k^(alpha-1) + 1 - delta)');
m.parameter('alpha', 0.36);
m.parameter('beta', 0.99);
m.parameter('delta', 0.025);
assert(isnan(m.c), 'c starts without a value.');
m.solve('k', 'k', 10);
kstar = (0.36/(1/0.99 - 1 + 0.025))^(1/(1 - 0.36));
assert(abs(m.k - kstar) < 1e-8, sprintf('k should be %g, got %g.', kstar, m.k));

% Solving for the symbol that cancels is refused: the equation does not determine it.
thrown = '';
try
    m.solve('k', 'c', 1);
catch ME
    thrown = ME.identifier;
end
assert(strcmp(thrown, 'modBuilder:solve:symbolCancels'), sprintf('Expected solve:symbolCancels, got "%s".', thrown));

% A symbol that remains without a value is named, instead of a NaN residual.
m2 = modBuilder();
m2.add('y', 'y = alpha*x + z');
m2.parameter('alpha', NaN);
m2.exogenous('x', 1);
m2.exogenous('z', NaN);
m2.endogenous('y', 0.5);
thrown = '';
message = '';
try
    m2.solve('y', 'alpha', 0.3);
catch ME
    thrown = ME.identifier;
    message = ME.message;
end
assert(strcmp(thrown, 'modBuilder:solve:missingValue') && contains(message, 'z'), sprintf('Expected solve:missingValue naming z, got "%s": %s', thrown, message));

% A negative value keeps its sign under a power.
m3 = modBuilder();
m3.add('y', 'y = a^2 + b');
m3.exogenous('a', -0.5);
m3.exogenous('b', 0);
m3.endogenous('y', 1);
m3.solve('y', 'y', 1);
assert(abs(m3.y - 0.25) < 1e-10, sprintf('y should be 0.25, got %g.', m3.y));

% STEADY_STATE(v) is read as v.
m4 = modBuilder();
m4.add('y', 'y = STEADY_STATE(k) + e');
m4.exogenous('k', 2);
m4.exogenous('e', 0);
m4.endogenous('y', 1);
m4.solve('y', 'y', 1);
assert(abs(m4.y - 2) < 1e-10, sprintf('y should be 2, got %g.', m4.y));
