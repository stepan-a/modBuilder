% Tests for endogenous metadata (long_name, tex_name, value)

m = modBuilder();
m.add('y', 'y = alpha*x');
m.add('c', 'c = beta*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('x', 1);

% Test 1: Set value and metadata on an endogenous variable
m.endogenous('y', 2.0, 'long_name', 'Output', 'texname', 'Y');
t = m.table('endogenous');
assert(t.Value(t.Name == 'y') == 2.0, ...
       'y value should be 2.0.');
assert(t.LongName(t.Name == 'y') == 'Output', ...
       'y should have long_name set.');
assert(t.TeXName(t.Name == 'y') == 'Y', ...
       'y should have tex_name set.');

% Test 2: Call endogenous without value (default NaN, then keep existing)
m.endogenous('c', [], 'long_name', 'Consumption', 'texname', 'C');
t = m.table('endogenous');
assert(t.LongName(t.Name == 'c') == 'Consumption', ...
       'c should have long_name set.');
assert(t.TeXName(t.Name == 'c') == 'C', ...
       'c should have tex_name set.');

% Test 3: Update only the value (no metadata change)
m.endogenous('y', 5.0);
t = m.table('endogenous');
assert(t.Value(t.Name == 'y') == 5.0, ...
       'y value should be updated to 5.0.');
assert(t.LongName(t.Name == 'y') == 'Output', ...
       'y long_name should remain unchanged.');
