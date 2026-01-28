% Tests for change errors

m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.parameter('alpha', 0.5);
m.exogenous('e', 0);
m.exogenous('x', 0);

% Test 1: No equation for variable
thrown = false;
try
    m.change('nonexistent', 'nonexistent = 0');
catch
    thrown = true;
end
assert(thrown, 'Expected error: no equation for variable.');

% Test 2: Change removes an exogenous variable
m2 = modBuilder();
m2.add('y', 'y = alpha*x + eps');
m2.add('c', 'c = beta*y');
m2.parameter('alpha', 0.5);
m2.parameter('beta', 0.8);
m2.exogenous('eps', 0);
m2.exogenous('x', 0);

assert(m2.isexogenous('eps'), 'eps should be exogenous before change.');
m2.change('y', 'y = alpha*x');
assert(~m2.isexogenous('eps'), 'eps should be removed after change.');
