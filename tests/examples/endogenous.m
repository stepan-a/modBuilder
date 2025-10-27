% Test examples from endogenous method documentation

m = modBuilder();
m.add('c', 'c = alpha*k');
m.parameter('alpha', 0.33);
m.exogenous('k', 1.0);

% Set value for endogenous variable
m.endogenous('c', 1.5);
assert(m.size('endogenous') == 1);
assert(m.var{1,2} == 1.5);

% With long name and TeX name
m2 = modBuilder();
m2.add('c', 'c = alpha*k');
m2.parameter('alpha', 0.33);
m2.exogenous('k', 1.0);
m2.endogenous('c', 1.5, 'long_name', 'Consumption', 'texname', 'C');
assert(m2.size('endogenous') == 1);
idx = find(strcmp(m2.var(:,1), 'c'));
assert(m2.var{idx,2} == 1.5);
assert(strcmp(m2.var{idx,3}, 'Consumption'));
assert(strcmp(m2.var{idx,4}, 'C'));

% Implicit loops - set values for multiple endogenous variables
m3 = modBuilder();
m3.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
m3.exogenous('A_$1', 1.0, {1, 2, 3});
m3.exogenous('K_$1', 1.0, {1, 2, 3});
m3.endogenous('Y_$1', 2.0, {1, 2, 3});
assert(m3.size('endogenous') == 3);
assert(any(strcmp(m3.var(:,1), 'Y_1')));
assert(any(strcmp(m3.var(:,1), 'Y_2')));
assert(any(strcmp(m3.var(:,1), 'Y_3')));
idx1 = find(strcmp(m3.var(:,1), 'Y_1'));
idx2 = find(strcmp(m3.var(:,1), 'Y_2'));
idx3 = find(strcmp(m3.var(:,1), 'Y_3'));
assert(m3.var{idx1,2} == 2.0);
assert(m3.var{idx2,2} == 2.0);
assert(m3.var{idx3,2} == 2.0);

% Implicit loops with TeX names
m4 = modBuilder();
m4.add('C_$1', 'C_$1 = Y_$1 - I_$1', {'FR', 'DE', 'IT'});
m4.exogenous('I_$1', 0.2, {'FR', 'DE', 'IT'});
m4.exogenous('Y_$1', 1.0, {'FR', 'DE', 'IT'});
m4.endogenous('C_$1', 0.8, 'texname', 'C^{$1}', {'FR', 'DE', 'IT'});
assert(m4.size('endogenous') == 3);
idx_FR = find(strcmp(m4.var(:,1), 'C_FR'));
idx_DE = find(strcmp(m4.var(:,1), 'C_DE'));
idx_IT = find(strcmp(m4.var(:,1), 'C_IT'));
assert(strcmp(m4.var{idx_FR,4}, 'C^{FR}'));
assert(strcmp(m4.var{idx_DE,4}, 'C^{DE}'));
assert(strcmp(m4.var{idx_IT,4}, 'C^{IT}'));

% Multiple indices with TeX formatting
m5 = modBuilder();
Countries = {'FR', 'DE'};
Sectors = {1, 2};
m5.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
m5.exogenous('A_$1_$2', 1.0, Countries, Sectors);
m5.exogenous('K_$1_$2', 1.0, Countries, Sectors);
m5.endogenous('Y_$1_$2', 1.0, ...
             'long_name', 'Output for $1 sector $2', ...
             'texname', 'Y_{$1,$2}', ...
             Countries, Sectors);
assert(m5.size('endogenous') == 4);
idx_FR_1 = find(strcmp(m5.var(:,1), 'Y_FR_1'));
assert(strcmp(m5.var{idx_FR_1,3}, 'Output for FR sector 1'));
assert(strcmp(m5.var{idx_FR_1,4}, 'Y_{FR,1}'));
idx_DE_2 = find(strcmp(m5.var(:,1), 'Y_DE_2'));
assert(strcmp(m5.var{idx_DE_2,3}, 'Output for DE sector 2'));
assert(strcmp(m5.var{idx_DE_2,4}, 'Y_{DE,2}'));

fprintf('endogenous.m: All tests passed\n');
