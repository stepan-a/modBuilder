% Tests for substitution and change that remove symbols (uncovered code paths)

% Test 1: change removes an exogenous variable (also tested in t09)
m = modBuilder();
m.add('y', 'y = alpha*x + beta*z + eps');
m.add('c', 'c = gamma*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.3);
m.parameter('gamma', 0.8);
m.exogenous('x', 0);
m.exogenous('z', 0);
m.exogenous('eps', 0);

% Replace equation: remove eps from equation y
m.change('y', 'y = alpha*x + beta*z');
assert(~m.isexogenous('eps'), 'eps should be removed after change.');

% Test 2: substitute (regex) removes a parameter and exogenous
% Replace "beta*z" with "x" in equation y using regex
m2 = modBuilder();
m2.add('y', 'y = alpha*x + beta*z');
m2.add('c', 'c = gamma*y');
m2.parameter('alpha', 0.5);
m2.parameter('beta', 0.3);
m2.parameter('gamma', 0.8);
m2.exogenous('x', 0);
m2.exogenous('z', 0);

m2.substitute('beta\*z', 'x', 'y');
assert(~m2.isparameter('beta'), 'beta should be removed after substitute.');
assert(~m2.isexogenous('z'), 'z should be removed after substitute.');

% Test 3: substitute (regex) removes an exogenous variable
m3 = modBuilder();
m3.add('y', 'y = alpha*x + delta');
m3.add('c', 'c = gamma*y');
m3.parameter('alpha', 0.5);
m3.parameter('gamma', 0.8);
m3.exogenous('x', 0);
m3.exogenous('delta', 0);

% Replace "alpha*x + delta" with "alpha*x" (remove delta term)
m3.substitute('alpha\*x \+ delta', 'alpha*x', 'y');
assert(~m3.isexogenous('delta'), 'delta should be removed after substitute.');
