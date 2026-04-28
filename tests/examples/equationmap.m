% Test examples from equationmap method documentation

m = modBuilder();
m.add('y', 'y = c + i');
m.add('c', 'c = (1-s)*y');
m.add('i', 'i = s*y');
m.parameter('s', 0.2);

% No-output form: prints to the console (smoke check, no assertion).
m.equationmap();

% Output form: returns a MATLAB table.
t = m.equationmap();

assert(isa(t, 'table'));
assert(height(t) == 3);
assert(isequal(t.Properties.VariableNames, {'Endogenous', 'Equation'}));

names = cellstr(t.Endogenous);
exprs = cellstr(t.Equation);
assert(any(strcmp(names, 'y')));
assert(any(strcmp(names, 'c')));
assert(any(strcmp(names, 'i')));
[~, k] = ismember('y', names);
assert(strcmp(exprs{k}, 'y = c + i'));

% Empty model returns a 0-row table with the same columns.
empty = modBuilder();
te = empty.equationmap();
assert(isa(te, 'table'));
assert(height(te) == 0);
assert(isequal(te.Properties.VariableNames, {'Endogenous', 'Equation'}));

fprintf('equationmap.m: All tests passed\n');
