% Tests for eq method: symbols differ (untyped symbols)

% Build reference model with all symbols typed
m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.add('c', 'c = beta*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('e', 0);
m.exogenous('x', 0);

% Test 1: One model has untyped symbols (x not declared as exogenous)
m2 = modBuilder();
m2.add('y', 'y = alpha*x + e');
m2.add('c', 'c = beta*y');
m2.parameter('alpha', 0.5);
m2.parameter('beta', 0.8);
m2.exogenous('e', 0);
% x stays untyped (in symbols, not declared as exogenous)
assert(~(m == m2), 'Should differ: untyped symbol x in m2.');

% Test 2: Both have same untyped symbols
m3 = modBuilder();
m3.add('y', 'y = alpha*x + e');
m3.add('c', 'c = beta*y');
m3.parameter('alpha', 0.5);
m3.parameter('beta', 0.8);
% e and x both untyped

m4 = modBuilder();
m4.add('y', 'y = alpha*x + e');
m4.add('c', 'c = beta*y');
m4.parameter('alpha', 0.5);
m4.parameter('beta', 0.8);
% e and x both untyped

assert(m3 == m4, 'Models with same untyped symbols should be equal.');

% Test 3: Different untyped symbols
m5 = modBuilder();
m5.add('y', 'y = alpha*x');
m5.add('c', 'c = beta*y');
m5.parameter('alpha', 0.5);
m5.parameter('beta', 0.8);
% x is untyped

m6 = modBuilder();
m6.add('y', 'y = alpha*z');
m6.add('c', 'c = beta*y');
m6.parameter('alpha', 0.5);
m6.parameter('beta', 0.8);
% z is untyped
assert(~(m5 == m6), 'Should differ: different untyped symbols.');
