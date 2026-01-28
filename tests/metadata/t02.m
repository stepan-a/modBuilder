% Tests for exogenous metadata (long_name, tex_name)

m = modBuilder();
m.add('y', 'y = alpha*x + beta*z');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.3);

% Test 1: Set long_name and tex_name on a new exogenous
m.exogenous('x', 0, 'long_name', 'Technology shock', 'texname', '\varepsilon_x');
t = m.table('exogenous');
assert(t.LongName(t.Name == 'x') == 'Technology shock', ...
       'x should have long_name set.');
assert(t.TeXName(t.Name == 'x') == '\varepsilon_x', ...
       'x should have tex_name set.');

% Test 2: Update metadata on an already-defined exogenous
m.exogenous('x', 1.0, 'long_name', 'Updated shock', 'texname', 'e_x');
t = m.table('exogenous');
assert(t.Value(t.Name == 'x') == 1.0, ...
       'x value should be updated.');
assert(t.LongName(t.Name == 'x') == 'Updated shock', ...
       'x long_name should be updated.');
assert(t.TeXName(t.Name == 'x') == 'e_x', ...
       'x tex_name should be updated.');

% Test 3: Convert parameter to exogenous with metadata
m.exogenous('alpha', 0.0, 'long_name', 'Shock alpha', 'texname', '\alpha');
assert(m.isexogenous('alpha'), 'alpha should now be exogenous.');
assert(~m.isparameter('alpha'), 'alpha should no longer be a parameter.');
t = m.table('exogenous');
assert(t.LongName(t.Name == 'alpha') == 'Shock alpha', ...
       'Converted alpha should have long_name.');
assert(t.TeXName(t.Name == 'alpha') == '\alpha', ...
       'Converted alpha should have tex_name.');

% Test 4: Set only tex_name (no long_name)
m.exogenous('z', 0, 'texname', 'Z');
t = m.table('exogenous');
assert(t.LongName(t.Name == 'z') == 'NA', ...
       'z should have no long_name (NA).');
assert(t.TeXName(t.Name == 'z') == 'Z', ...
       'z should have tex_name set.');
