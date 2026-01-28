% Tests for eq method: equations differ

% Build reference model
m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.add('c', 'c = beta*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('e', 0);
m.exogenous('x', 0);

% Test 1: Different equation text
m2 = m.copy();
m2.change('y', 'y = alpha*x');
assert(~(m == m2), 'Should differ: equation text changed.');

% Test 2: Different number of equations
m3 = modBuilder();
m3.add('y', 'y = alpha*x + e');
m3.add('c', 'c = beta*y');
m3.add('i', 'i = gamma*y');
m3.parameter('alpha', 0.5);
m3.parameter('beta', 0.8);
m3.parameter('gamma', 0.3);
m3.exogenous('e', 0);
m3.exogenous('x', 0);
assert(~(m == m3), 'Should differ: different number of equations.');
