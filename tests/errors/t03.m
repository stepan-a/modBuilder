% Tests for exogenous declaration errors

m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.parameter('alpha', 0.5);
m.exogenous('e', 0);
m.exogenous('x', 0);

% Test 1: Cannot convert endogenous to exogenous
thrown = false;
try
    m.exogenous('y', 0);
catch
    thrown = true;
end
assert(thrown, 'Expected error: endogenous cannot become exogenous.');

% Test 2: Unknown symbol
thrown = false;
try
    m.exogenous('nonexistent', 0);
catch
    thrown = true;
end
assert(thrown, 'Expected error: unknown symbol.');
