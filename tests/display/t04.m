% Tests for the disp() overload (compact one-line model description).

% Test 1: a well-formed model reports counts, calibrated parameters, and an
% up-to-date status once the symbol tables have been refreshed.
m = modBuilder();
m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
m.parameter('alpha', 0.36);
m.parameter('delta', 0.025);
m.exogenous('k', 10);
m.updatesymboltables();   % force tables current

s = evalc('disp(m)');
assert(contains(s, '2 endogenous'),          'expected 2 endogenous, got: %s', s);
assert(contains(s, '1 exogenous'),           'expected 1 exogenous, got: %s', s);
assert(contains(s, '2 parameters (2 calibrated)'), 'expected calibrated count, got: %s', s);
assert(contains(s, '2 equations'),           'expected 2 equations, got: %s', s);
assert(contains(s, 'up to date'),            'expected up-to-date status, got: %s', s);
assert(~contains(s, 'untyped'),              'no untyped symbols expected, got: %s', s);

% Test 2: a structural change marks the symbol tables stale.
m.add('i', 'i = delta*k');
s = evalc('disp(m)');
assert(contains(s, 'stale'), 'expected stale status after add(), got: %s', s);

% Test 3: an uncalibrated parameter is reflected in the calibrated count.
m2 = modBuilder();
m2.add('y', 'y = beta*x');
m2.parameter('beta', NaN);
m2.exogenous('x', 1);
s = evalc('disp(m2)');
assert(contains(s, '1 parameters (0 calibrated)'), 'expected 0 calibrated, got: %s', s);

% Test 4: a model with no parameters takes the "0 parameters" branch.
m3 = modBuilder();
m3.add('y', 'y = x');
m3.exogenous('x', 0);
s = evalc('disp(m3)');
assert(contains(s, '0 parameters'), 'expected 0-parameters branch, got: %s', s);

% Test 5: untyped symbols are listed.
m4 = modBuilder();
m4.add('y', 'y = alpha*x + e');
m4.parameter('alpha', 0.5);   % x and e remain untyped
s = evalc('disp(m4)');
assert(contains(s, 'untyped'), 'expected untyped-symbol warning, got: %s', s);
assert(contains(s, 'x') && contains(s, 'e'), 'expected untyped names listed, got: %s', s);

% Test 6: bare-expression auto-display routes through disp (default display
% wraps it with the variable name). Just check it does not error and uses
% the compact form.
s = evalc('m3');
assert(contains(s, 'modBuilder:'), 'auto-display should use the compact disp, got: %s', s);
