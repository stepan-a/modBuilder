% Test examples from exogenous method documentation

m = modBuilder();
m.add('y', 'y = a + epsilon');
m.parameter('a', 1.5);

% Declare exogenous variable with default value
m.exogenous('epsilon', 0);
assert(m.size('exogenous') == 1);
assert(m.varexo{1,2} == 0);

% Declare without setting value (defaults to NaN)
m.add('z', 'z = u');
m.exogenous('u');
assert(m.size('exogenous') == 2);
idx = find(strcmp(m.varexo(:,1), 'u'));
assert(isnan(m.varexo{idx,2}));

% With long name and TeX name
m.add('w', 'w = e');
m.exogenous('e', 0, 'long_name', 'Technology shock', 'texname', '\varepsilon');
assert(m.size('exogenous') == 3);
idx = find(strcmp(m.varexo(:,1), 'e'));
assert(m.varexo{idx,2} == 0);
assert(strcmp(m.varexo{idx,3}, 'Technology shock'));
assert(strcmp(m.varexo{idx,4}, '\varepsilon'));

fprintf('exogenous.m: All tests passed\n');
