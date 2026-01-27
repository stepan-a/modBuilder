% Test examples from select method documentation

% Build a model with tagged equations
m = modBuilder();
m.add('Y_m', 'Y_m = A_m*K_m^alpha_m*L_m^(1-alpha_m)');
m.add('Y_s', 'Y_s = A_s*K_s^alpha_s*L_s^(1-alpha_s)');
m.add('C', 'C = Y_m + Y_s');
m.parameter('A_m', 1.0);
m.parameter('A_s', 1.0);
m.parameter('alpha_m', 0.33);
m.parameter('alpha_s', 0.50);
m.exogenous('L_m', 1.0);
m.exogenous('L_s', 1.0);

% Tag equations
m.tag('Y_m', 'sector', 'manufacturing');
m.tag('Y_s', 'sector', 'services');
m.tag('C', 'type', 'aggregation');

% Test 1: select returns a modBuilder with matching equations
sub = m.select('sector', 'manufacturing');
assert(isa(sub, 'modBuilder'));
assert(sub.size('endogenous') == 1);
assert(strcmp(sub.equations{1,1}, 'Y_m'));

% Test 2: select with regex
sub = m.select('sector', '.*');
assert(sub.size('endogenous') == 2);
assert(all(ismember({'Y_m', 'Y_s'}, sub.equations(:,1))));

% Test 3: selected submodel has correct parameters
sub = m.select('sector', 'manufacturing');
assert(any(strcmp(sub.params(:,1), 'A_m')));
assert(any(strcmp(sub.params(:,1), 'alpha_m')));
assert(~any(strcmp(sub.params(:,1), 'A_s')));
assert(~any(strcmp(sub.params(:,1), 'alpha_s')));

% Test 4: bytag with subsref {} indexing
sub2 = m{bytag('sector', 'manufacturing')};
assert(isa(sub2, 'modBuilder'));
assert(sub2.size('endogenous') == 1);
assert(strcmp(sub2.equations{1,1}, 'Y_m'));

% Test 5: bytag with multiple criteria
sub3 = m{bytag('sector', 'services')};
assert(sub3.size('endogenous') == 1);
assert(strcmp(sub3.equations{1,1}, 'Y_s'));

% Test 6: select and bytag give identical results
sub_select = m.select('sector', 'manufacturing');
sub_bytag = m{bytag('sector', 'manufacturing')};
assert(sub_select == sub_bytag);

fprintf('select.m: All tests passed\n');
