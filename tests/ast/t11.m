% shift_lag: lag-shift every time-varying variable in a tree.

% Basic shift: a sym becomes a tsym
n = ast('y');
r = n.shift_lag(-1);
expected = ast('y(-1)');
assert(ast.ast_equal(r, expected), 'sym → tsym(-1)');

% Positive shift (lead)
r = ast('y').shift_lag(1);
expected = ast('y(1)');
assert(ast.ast_equal(r, expected), 'sym → tsym(+1)');

% k = 0 is a no-op
n = ast('alpha + x(-1)');
r = n.shift_lag(0);
assert(ast.ast_equal(r, n), 'k=0 is identity');

% Shifting a tsym composes lags
n = ast('y(-1)');
r = n.shift_lag(-2);
expected = ast('y(-3)');
assert(ast.ast_equal(r, expected), 'lag composition (-1) + (-2) = -3');

% Shift collapses tsym back to sym when total lag is 0
n = ast('y(-1)');
r = n.shift_lag(1);
expected = ast('y');
assert(ast.ast_equal(r, expected), 'collapse to sym at lag 0');

% Parameters are not shifted
n = ast('theta * x');
r = n.shift_lag(-1, {'theta'});
expected = ast('theta * x(-1)');
assert(ast.ast_equal(r, expected), 'parameters are not shifted');

% Numbers are not shifted
n = ast('0.5 + x');
r = n.shift_lag(-1);
expected = ast('0.5 + x(-1)');
assert(ast.ast_equal(r, expected), 'numbers are not shifted');

% STEADY_STATE is time-invariant
n = ast('STEADY_STATE(x) + x');
r = n.shift_lag(-1);
expected = ast('STEADY_STATE(x) + x(-1)');
assert(ast.ast_equal(r, expected), 'STEADY_STATE is time-invariant');

% Shift descends into function calls
n = ast('exp(x)');
r = n.shift_lag(-1);
expected = ast('exp(x(-1))');
assert(ast.ast_equal(r, expected), 'shift inside call');

% Shift descends into binop
n = ast('x + y');
r = n.shift_lag(1);
expected = ast('x(1) + y(1)');
assert(ast.ast_equal(r, expected), 'shift inside binop');

% Shift descends into uminus
n = ast('-x');
r = n.shift_lag(-1);
expected = ast('-x(-1)');
assert(ast.ast_equal(r, expected), 'shift inside uminus');

% Mixed parameters and variables in a realistic expression
n = ast('theta * w / (mpl + 1)');
r = n.shift_lag(-1, {'theta'});
expected = ast('theta * w(-1) / (mpl(-1) + 1)');
assert(ast.ast_equal(r, expected), 'mixed parameters and variables');

% shift_lag is a value-class operation: the original tree must be unchanged
n = ast('x + y');
m = n.shift_lag(-1);
assert(ast.ast_equal(n, ast('x + y')), 'shift_lag does not mutate');
