% Test examples from parameter method documentation

m = modBuilder();
m.add('c', 'c = alpha*k');

% Calibrate a parameter
m.parameter('alpha', 0.33);
assert(m.size('parameters') == 1);
assert(m.params{1,2} == 0.33);

% Declare uncalibrated parameter
m.add('y', 'y = beta*k');
m.parameter('beta');  % value will be NaN
assert(m.size('parameters') == 2);
assert(isnan(m.params{2,2}));

% With long name and TeX name
m.add('z', 'z = rho*x');
m.parameter('rho', 0.95, 'long_name', 'Persistence', 'texname', '\rho');
assert(m.size('parameters') == 3);
idx = find(strcmp(m.params(:,1), 'rho'));
assert(m.params{idx,2} == 0.95);
assert(strcmp(m.params{idx,3}, 'Persistence'));
assert(strcmp(m.params{idx,4}, '\rho'));

% Implicit loops - create multiple parameters
m2 = modBuilder();
m2.add('y', 'y = gamma_1 + gamma_2 + gamma_3');
m2.parameter('gamma_$1', 0.5, {1, 2, 3});
assert(m2.size('parameters') == 3);
assert(any(strcmp(m2.params(:,1), 'gamma_1')));
assert(any(strcmp(m2.params(:,1), 'gamma_2')));
assert(any(strcmp(m2.params(:,1), 'gamma_3')));

fprintf('parameter.m: All tests passed\n');
