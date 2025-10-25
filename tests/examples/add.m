% Test examples from add method documentation

% Simple equation
m = modBuilder();
m.add('c', 'c = w*h');

% Verify equation was added
assert(m.size('endogenous') == 1);
assert(strcmp(m.equations{1,1}, 'c'));
assert(strcmp(m.equations{1,2}, 'c = w*h'));

% Equation with lags and leads
m.add('k', 'k = (1-delta)*k(-1) + i');
m.add('r', '1/beta = (c/c(+1))*(r(+1)+1-delta)');

% Verify equations were added
assert(m.size('endogenous') == 3);

% With implicit loops
m2 = modBuilder();
m2.add('x_$1', 'x_$1 = alpha_$1 * y', {1, 2, 3});

% Verify implicit loop created 3 equations
assert(m2.size('endogenous') == 3);
assert(any(strcmp(m2.equations(:,1), 'x_1')));
assert(any(strcmp(m2.equations(:,1), 'x_2')));
assert(any(strcmp(m2.equations(:,1), 'x_3')));

fprintf('add.m: All tests passed\n');
