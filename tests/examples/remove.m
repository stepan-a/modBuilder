% Test examples from remove method documentation

m = modBuilder();
m.add('c', 'c = w*h');
m.add('y', 'y = c + i');
m.parameter('w', 1.5);
% Type remaining symbols
m.exogenous('h', NaN);
m.exogenous('i', NaN);

% Remove the consumption equation
initial_eqs = m.size('endogenous');
m.remove('c');  % Also removes h if it doesn't appear elsewhere

% Verify equation was removed
assert(m.size('endogenous') == initial_eqs - 1);
assert(~any(strcmp(m.equations(:,1), 'c')));

% Implicit loops - remove multiple equations
m2 = modBuilder();
m2.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
m2.parameter('A_$1', 1.0, {1, 2, 3});
m2.exogenous('K_$1', 1.0, {1, 2, 3});
assert(m2.size('endogenous') == 3);
m2.remove('Y_$1', {1, 3});  % Removes Y_1 and Y_3, keeps Y_2
assert(m2.size('endogenous') == 1);
assert(strcmp(m2.equations{1,1}, 'Y_2'));
assert(~any(strcmp(m2.equations(:,1), 'Y_1')));
assert(~any(strcmp(m2.equations(:,1), 'Y_3')));

% Multiple indices
m3 = modBuilder();
Countries = {'FR', 'DE'};
Sectors = {1, 2};
m3.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
m3.parameter('A_$1_$2', 1.0, Countries, Sectors);
m3.exogenous('K_$1_$2', 1.0, Countries, Sectors);
assert(m3.size('endogenous') == 4);
m3.remove('Y_$1_$2', {'FR'}, {1, 2});  % Removes Y_FR_1 and Y_FR_2
assert(m3.size('endogenous') == 2);
assert(any(strcmp(m3.equations(:,1), 'Y_DE_1')));
assert(any(strcmp(m3.equations(:,1), 'Y_DE_2')));
assert(~any(strcmp(m3.equations(:,1), 'Y_FR_1')));
assert(~any(strcmp(m3.equations(:,1), 'Y_FR_2')));

fprintf('remove.m: All tests passed\n');
