% Tests for parameter metadata (long_name, tex_name)

m = modBuilder();
m.add('y', 'y = alpha*x + beta*z');
m.exogenous('x', 0);
m.exogenous('z', 0);

% Test 1: Set long_name and tex_name on a new parameter
m.parameter('alpha', 0.5, 'long_name', 'Capital share', 'texname', '\alpha');
t = m.table('parameters');
assert(t.LongName(t.Name == 'alpha') == 'Capital share', ...
       'alpha should have long_name set.');
assert(t.TeXName(t.Name == 'alpha') == '\alpha', ...
       'alpha should have tex_name set.');

% Test 2: Update metadata on an already-defined parameter
m.parameter('alpha', 0.6, 'long_name', 'Updated share', 'texname', '\hat{\alpha}');
t = m.table('parameters');
assert(t.Value(t.Name == 'alpha') == 0.6, ...
       'alpha value should be updated.');
assert(t.LongName(t.Name == 'alpha') == 'Updated share', ...
       'alpha long_name should be updated.');
assert(t.TeXName(t.Name == 'alpha') == '\hat{\alpha}', ...
       'alpha tex_name should be updated.');

% Test 3: Convert exogenous to parameter with metadata
m.parameter('x', 1.0, 'long_name', 'Productivity', 'texname', 'X');
assert(m.isparameter('x'), 'x should now be a parameter.');
assert(~m.isexogenous('x'), 'x should no longer be exogenous.');
t = m.table('parameters');
assert(t.LongName(t.Name == 'x') == 'Productivity', ...
       'Converted x should have long_name.');
assert(t.TeXName(t.Name == 'x') == 'X', ...
       'Converted x should have tex_name.');

% Test 4: Set only long_name (no tex_name)
m.parameter('beta', 0.3, 'long_name', 'Elasticity');
t = m.table('parameters');
assert(t.LongName(t.Name == 'beta') == 'Elasticity', ...
       'beta should have long_name.');
assert(t.TeXName(t.Name == 'beta') == 'NA', ...
       'beta should have no tex_name (NA).');
