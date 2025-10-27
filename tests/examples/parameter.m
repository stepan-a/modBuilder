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

% Implicit loops with TeX names
m3 = modBuilder();
m3.add('c', 'c = alpha_1*k + alpha_2*l + alpha_3*m');
m3.parameter('alpha_$1', 0.33, 'texname', '\alpha_{$1}', {1, 2, 3});
assert(m3.size('parameters') == 3);
idx1 = find(strcmp(m3.params(:,1), 'alpha_1'));
idx2 = find(strcmp(m3.params(:,1), 'alpha_2'));
idx3 = find(strcmp(m3.params(:,1), 'alpha_3'));
assert(strcmp(m3.params{idx1,4}, '\alpha_{1}'));
assert(strcmp(m3.params{idx2,4}, '\alpha_{2}'));
assert(strcmp(m3.params{idx3,4}, '\alpha_{3}'));

% Multiple indices with TeX formatting
m4 = modBuilder();
Countries = {'FR', 'DE', 'IT'};
Sectors = {1, 2};
m4.add('Y_$1_$2', 'Y_$1_$2 = rho_$1_$2*K_$1_$2', Countries, Sectors);
m4.parameter('rho_$1_$2', 0.9, ...
            'long_name', 'Persistence for $1 sector $2', ...
            'texname', '\rho_{$1,$2}', ...
            Countries, Sectors);
assert(m4.size('parameters') == 6);
idx_FR_1 = find(strcmp(m4.params(:,1), 'rho_FR_1'));
assert(strcmp(m4.params{idx_FR_1,3}, 'Persistence for FR sector 1'));
assert(strcmp(m4.params{idx_FR_1,4}, '\rho_{FR,1}'));
idx_DE_2 = find(strcmp(m4.params(:,1), 'rho_DE_2'));
assert(strcmp(m4.params{idx_DE_2,3}, 'Persistence for DE sector 2'));
assert(strcmp(m4.params{idx_DE_2,4}, '\rho_{DE,2}'));

fprintf('parameter.m: All tests passed\n');
