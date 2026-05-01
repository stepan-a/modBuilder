% substitute: lag-aware tree-based replacement of a symbol by an AST subtree.

% Basic substitution: replace a sym with a more complex expression
n = ast('alpha + beta');
r = n.substitute('alpha', ast('1 - gamma'));
expected = ast('1 - gamma + beta');
assert(ast.ast_equal(r, expected), 'basic sym substitution');

% Replacement can be passed as a string (auto-parsed)
r = ast('alpha + beta').substitute('alpha', '1 - gamma');
assert(ast.ast_equal(r, expected), 'string replacement is auto-parsed');

% Word-boundary safety: substituting "k" must not touch "k_bar"
n = ast('k_bar + k');
r = n.substitute('k', 'x + y');
expected = ast('k_bar + (x + y)');
assert(ast.ast_equal(r, expected), 'no substring match');

% Precedence is preserved by construction (key fix vs strrep):
% substituting x by y+z in a*x^2 must give a*(y+z)^2, not a*y+z^2
n = ast('a * x^2');
r = n.substitute('x', 'y + z');
expected = ast('a * (y + z)^2');
assert(ast.ast_equal(r, expected), 'precedence preserved through substitution');

% Lag-aware substitution: tsym matches lag-shift the replacement
n = ast('x(-1) + 1');
r = n.substitute('x', 'y + z');
expected = ast('(y(-1) + z(-1)) + 1');
assert(ast.ast_equal(r, expected), 'tsym match lag-shifts replacement');

% Parameter exclusion: parameters in the replacement are not lag-shifted
n = ast('mc(-1)');
r = n.substitute('mc', 'theta * w / mpl', {'theta'});
expected = ast('theta * w(-1) / mpl(-1)');
assert(ast.ast_equal(r, expected), 'parameters are not lag-shifted');

% Lag composition: a tsym in the replacement gets cumulative lag
n = ast('x(-1)');
r = n.substitute('x', 'y(-1)');
expected = ast('y(-2)');
assert(ast.ast_equal(r, expected), 'lags compose');

% Lag composition collapses to sym when total lag is 0
n = ast('x(+1)');
r = n.substitute('x', 'y(-1)');
expected = ast('y');
assert(ast.ast_equal(r, expected), 'lag composition collapses to sym at lag 0');

% STEADY_STATE inside the replacement is time-invariant
n = ast('mc(-1)');
r = n.substitute('mc', 'STEADY_STATE(w) + alpha', {'alpha'});
expected = ast('STEADY_STATE(w) + alpha');
assert(ast.ast_equal(r, expected), 'STEADY_STATE in replacement not shifted');

% Substitution descends into function calls
n = ast('exp(alpha + beta)');
r = n.substitute('alpha', 'A + B');
expected = ast('exp((A + B) + beta)');
assert(ast.ast_equal(r, expected), 'inside call');

% Substitution descends into uminus
n = ast('-alpha + 1');
r = n.substitute('alpha', '2*beta');
expected = ast('-(2*beta) + 1');
assert(ast.ast_equal(r, expected), 'inside uminus');

% Absent symbol leaves the tree untouched
n = ast('a + b');
r = n.substitute('c', 'x');
assert(ast.ast_equal(r, n), 'no-op for absent symbol');

% STEADY_STATE leaves of the host tree are not entered
n = ast('STEADY_STATE(x) + x');
r = n.substitute('x', 'y');
expected = ast('STEADY_STATE(x) + y');
assert(ast.ast_equal(r, expected), 'host ss left untouched');

% Substitute is a value-class operation: the original tree must be unchanged
n = ast('alpha + beta');
m = n.substitute('alpha', 'gamma');
assert(ast.ast_equal(n, ast('alpha + beta')), 'substitute does not mutate');

% Phillips-curve fragment: the motivating example
n = ast('pi - beta * mc(-1)');
r = n.substitute('mc', 'w / mpl');
expected = ast('pi - beta * (w(-1) / mpl(-1))');
assert(ast.ast_equal(r, expected), 'motivating example: mc → w/mpl');
