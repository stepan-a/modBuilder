% Tests for eq method: params differ (isequalcell branches)

% Build reference model
m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.add('c', 'c = beta*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('e', 0);
m.exogenous('x', 0);

% Test 1: Different parameter value
m2 = m.copy();
m2.alpha = 0.9;
assert(~(m == m2), 'Should differ: parameter value changed.');

% Test 2: Different number of parameters (extra param in m2)
m3 = modBuilder();
m3.add('y', 'y = alpha*x + gamma*e');
m3.add('c', 'c = beta*y');
m3.parameter('alpha', 0.5);
m3.parameter('beta', 0.8);
m3.parameter('gamma', 1.0);
m3.exogenous('e', 0);
m3.exogenous('x', 0);
assert(~(m == m3), 'Should differ: different number of parameters.');

% Test 3: NaN parameter value vs calibrated value
m4 = m.copy();
m4.alpha = NaN;
assert(~(m == m4), 'Should differ: NaN vs calibrated value.');

% Test 4: Both NaN should be equal (NaN pattern match)
m5 = m.copy();
m5.alpha = NaN;
m6 = m.copy();
m6.alpha = NaN;
assert(m5 == m6, 'Models with matching NaN pattern should be equal.');
