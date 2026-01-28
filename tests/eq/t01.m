% Tests for eq method: identical models (positive tests)

% Test 1: A model should be equal to its copy
m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.add('c', 'c = beta*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('e', 0);
m.exogenous('x', 0);

m2 = m.copy();
assert(m == m2, 'A model should be equal to its copy.');

% Test 2: Two independently built identical models should be equal
m3 = modBuilder();
m3.add('y', 'y = alpha*x + e');
m3.add('c', 'c = beta*y');
m3.parameter('alpha', 0.5);
m3.parameter('beta', 0.8);
m3.exogenous('e', 0);
m3.exogenous('x', 0);

assert(m == m3, 'Two independently built identical models should be equal.');

% Test 3: Equality is symmetric
assert(m2 == m, 'Equality should be symmetric (copy == original).');
assert(m3 == m, 'Equality should be symmetric (independent == original).');

% Test 4: Empty models should be equal
m4 = modBuilder();
m5 = modBuilder();
assert(m4 == m5, 'Two empty models should be equal.');
