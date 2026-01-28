% Tests for remove() endogenous cleanup (line 2081-2082)

% When removing an equation, if the endogenous variable only appears
% in that equation, it should be removed from var.

m = modBuilder();
m.add('y', 'y = alpha*x');
m.add('c', 'c = beta*z');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('x', 0);
m.exogenous('z', 0);

% y only appears in its own equation, not in c's equation
assert(m.isendogenous('y'), 'y should be endogenous before removal.');
m.remove('y');
assert(~m.isendogenous('y'), 'y should be removed from var after equation removal.');
assert(~m.isparameter('alpha'), 'alpha should be removed (only used in y equation).');
assert(~m.isexogenous('x'), 'x should be removed (only used in y equation).');

% c and its symbols should remain
assert(m.isendogenous('c'), 'c should still be endogenous.');
assert(m.isparameter('beta'), 'beta should still be a parameter.');
assert(m.isexogenous('z'), 'z should still be exogenous.');
