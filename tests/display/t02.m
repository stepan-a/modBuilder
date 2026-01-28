% Tests for table() method edge cases

% Test 1: Invalid type argument (error branch, line 2789)
m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 0);
thrown = false;
try
    m.table('invalid');
catch
    thrown = true;
end
assert(thrown, 'Expected error for invalid type argument.');

% Test 2: Empty table (no exogenous, lines 2795-2796)
m2 = modBuilder();
m2.add('y', 'y = alpha');
m2.parameter('alpha', 0.5);
t = m2.table('exogenous');
assert(isempty(t), 'Table should be empty for no exogenous variables.');

% Test 3: Table with metadata values (lines 2811, 2817)
m3 = modBuilder();
m3.add('y', 'y = alpha*x');
m3.parameter('alpha', 0.5, 'long_name', 'Capital share', 'texname', '\alpha');
m3.exogenous('x', 0);
t = m3.table('parameters');
assert(t.LongName(1) == 'Capital share', ...
       'LongName should display actual value, not NA.');
assert(t.TeXName(1) == '\alpha', ...
       'TeXName should display actual value, not NA.');

% Test 4: Table with mixed metadata (some empty, some set)
m4 = modBuilder();
m4.add('y', 'y = alpha*x + beta*z');
m4.parameter('alpha', 0.5, 'long_name', 'Share');
m4.parameter('beta', 0.3);
m4.exogenous('x', 0);
m4.exogenous('z', 0);
t = m4.table('parameters');
assert(t.LongName(t.Name == 'alpha') == 'Share', ...
       'alpha should show long_name.');
assert(t.LongName(t.Name == 'beta') == 'NA', ...
       'beta should show NA for long_name.');
