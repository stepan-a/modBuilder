% Tests for eq method: varexo differ

% Build reference model
m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.add('c', 'c = beta*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('e', 0);
m.exogenous('x', 0);

% Test 1: Different exogenous value
m2 = m.copy();
m2.x = 999;
assert(~(m == m2), 'Should differ: exogenous value changed.');

% Test 2: Different number of exogenous variables
m3 = modBuilder();
m3.add('y', 'y = alpha*x + e + z');
m3.add('c', 'c = beta*y');
m3.parameter('alpha', 0.5);
m3.parameter('beta', 0.8);
m3.exogenous('e', 0);
m3.exogenous('x', 0);
m3.exogenous('z', 0);
assert(~(m == m3), 'Should differ: different number of exogenous variables.');

% Test 3: Same names, different values
m4 = m.copy();
m4.e = 1.5;
assert(~(m == m4), 'Should differ: exogenous e has different value.');
