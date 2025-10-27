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

% Implicit loops with TeX names
m2 = modBuilder();
m2.add('Y', 'Y = A_FR + A_DE + A_IT');
m2.exogenous('A_$1', 1.0, 'texname', 'A^{$1}', {'FR', 'DE', 'IT'});
assert(m2.size('exogenous') == 3);
idx_FR = find(strcmp(m2.varexo(:,1), 'A_FR'));
idx_DE = find(strcmp(m2.varexo(:,1), 'A_DE'));
idx_IT = find(strcmp(m2.varexo(:,1), 'A_IT'));
assert(strcmp(m2.varexo{idx_FR,4}, 'A^{FR}'));
assert(strcmp(m2.varexo{idx_DE,4}, 'A^{DE}'));
assert(strcmp(m2.varexo{idx_IT,4}, 'A^{IT}'));

% Multiple indices with TeX formatting
m3 = modBuilder();
Countries = {'FR', 'DE'};
Sectors = {1, 2, 3};
m3.add('Y_$1_$2', 'Y_$1_$2 = K_$1_$2', Countries, Sectors);
m3.exogenous('K_$1_$2', 1.0, ...
            'long_name', 'Capital in $1 sector $2', ...
            'texname', 'K^{$1}_{$2}', ...
            Countries, Sectors);
assert(m3.size('exogenous') == 6);
idx_FR_1 = find(strcmp(m3.varexo(:,1), 'K_FR_1'));
assert(strcmp(m3.varexo{idx_FR_1,3}, 'Capital in FR sector 1'));
assert(strcmp(m3.varexo{idx_FR_1,4}, 'K^{FR}_{1}'));
idx_DE_3 = find(strcmp(m3.varexo(:,1), 'K_DE_3'));
assert(strcmp(m3.varexo{idx_DE_3,3}, 'Capital in DE sector 3'));
assert(strcmp(m3.varexo{idx_DE_3,4}, 'K^{DE}_{3}'));

fprintf('exogenous.m: All tests passed\n');
