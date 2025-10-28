% Test examples from tag method documentation

% Basic usage
m = modBuilder();
m.add('Y', 'Y = A*K');
m.parameter('A', 1.0);
m.exogenous('K', 1.0);
m.tag('Y', 'desc', 'Production function');

% Verify tag was set
assert(strcmp(m.tags.Y.desc, 'Production function'));

% Implicit loops - tag multiple equations
m2 = modBuilder();
m2.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
m2.parameter('A_$1', 1.0, {1, 2, 3});
m2.exogenous('K_$1', 1.0, {1, 2, 3});
m2.tag('Y_$1', 'desc', 'Production function for sector $1', {1, 2, 3});

% Verify tags
assert(strcmp(m2.tags.Y_1.desc, 'Production function for sector 1'));
assert(strcmp(m2.tags.Y_2.desc, 'Production function for sector 2'));
assert(strcmp(m2.tags.Y_3.desc, 'Production function for sector 3'));

% Multiple indices
Countries = {'FR', 'DE'};
Sectors = {1, 2};
m3 = modBuilder();
m3.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
m3.parameter('A_$1_$2', 1.0, Countries, Sectors);
m3.exogenous('K_$1_$2', 1.0, Countries, Sectors);
m3.tag('Y_$1_$2', 'desc', 'Production for $1 in sector $2', Countries, Sectors);

% Verify tags for all combinations
assert(strcmp(m3.tags.Y_FR_1.desc, 'Production for FR in sector 1'));
assert(strcmp(m3.tags.Y_FR_2.desc, 'Production for FR in sector 2'));
assert(strcmp(m3.tags.Y_DE_1.desc, 'Production for DE in sector 1'));
assert(strcmp(m3.tags.Y_DE_2.desc, 'Production for DE in sector 2'));

fprintf('tag.m: All tests passed\n');
