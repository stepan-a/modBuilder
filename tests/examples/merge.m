% Test examples from merge method documentation

% Create first model (consumption block)
m1 = modBuilder();
m1.add('c', 'c = w*h');
m1.parameter('w', 1.5);

% Create second model (production block)
m2 = modBuilder();
m2.add('y', 'y = alpha*k');
m2.parameter('alpha', 0.33);

% Merge the two models
full_model = m1.merge(m2);

% Verify full_model contains both equations and all parameters
assert(full_model.size('endogenous') == 2);
assert(full_model.size('parameters') == 2);
assert(any(strcmp(full_model.equations(:,1), 'c')));
assert(any(strcmp(full_model.equations(:,1), 'y')));
assert(any(strcmp(full_model.params(:,1), 'w')));
assert(any(strcmp(full_model.params(:,1), 'alpha')));

fprintf('merge.m: All tests passed\n');
