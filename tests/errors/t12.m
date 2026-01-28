% Tests for eq operator (==) errors and inequality branches

% Build a reference model
m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.add('c', 'c = beta*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('e', 0);
m.exogenous('x', 0);

% Test 1: Non-modBuilder comparison
thrown = false;
try
    m == 42;
catch
    thrown = true;
end
assert(thrown, 'Expected error: cannot compare with non-modBuilder.');

% Test 2: Identical models
m2 = m.copy();
assert(m == m2, 'Identical models should be equal.');

% Test 3: Different params (change value via public API)
m2 = m.copy();
m2.alpha = 0.9;
assert(~(m == m2), 'Should differ: params value.');

% Test 4: Different varexo (change value via dot notation)
m2 = m.copy();
m2.x = 999;
assert(~(m == m2), 'Should differ: varexo value.');

% Test 5: Different var (change value via dot notation)
m2 = m.copy();
m2.y = 999;
assert(~(m == m2), 'Should differ: var value.');

% Test 6: Different symbols (one model has untyped symbols)
m3 = modBuilder();
m3.add('y', 'y = alpha*x + e');
m3.add('c', 'c = beta*y');
m3.parameter('alpha', 0.5);
m3.parameter('beta', 0.8);
m3.exogenous('e', 0);
% x stays untyped (in symbols)
assert(~(m == m3), 'Should differ: untyped symbols.');

% Test 7: Different equations
m2 = m.copy();
m2.change('y', 'y = alpha*x');
assert(~(m == m2), 'Should differ: equations.');

% Test 8: Different tags
m2 = m.copy();
m2.tag('y', 'description', 'Output equation');
assert(~(m == m2), 'Should differ: tags.');
