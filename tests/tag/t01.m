addpath ../utils

% Test implicit loops in tag method

% Test 1: Single index implicit loop
m1 = modBuilder();
m1.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
m1.parameter('A_$1', 1.0, {1, 2, 3});
m1.exogenous('K_$1', 1.0, {1, 2, 3});

% Tag all three equations with indexed values
m1.tag('Y_$1', 'desc', 'Production function for sector $1', {1, 2, 3});

% Verify tags were set correctly
assert(strcmp(m1.tags.Y_1.desc, 'Production function for sector 1'));
assert(strcmp(m1.tags.Y_2.desc, 'Production function for sector 2'));
assert(strcmp(m1.tags.Y_3.desc, 'Production function for sector 3'));

% Test 2: Multiple indices implicit loop
Countries = {'FR', 'DE', 'IT'};
Sectors = {1, 2};
m2 = modBuilder();
m2.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
m2.parameter('A_$1_$2', 1.0, Countries, Sectors);
m2.exogenous('K_$1_$2', 1.0, Countries, Sectors);

% Tag all combinations
m2.tag('Y_$1_$2', 'desc', 'Production for $1 in sector $2', Countries, Sectors);

% Verify tags
assert(strcmp(m2.tags.Y_FR_1.desc, 'Production for FR in sector 1'));
assert(strcmp(m2.tags.Y_FR_2.desc, 'Production for FR in sector 2'));
assert(strcmp(m2.tags.Y_DE_1.desc, 'Production for DE in sector 1'));
assert(strcmp(m2.tags.Y_DE_2.desc, 'Production for DE in sector 2'));
assert(strcmp(m2.tags.Y_IT_1.desc, 'Production for IT in sector 1'));
assert(strcmp(m2.tags.Y_IT_2.desc, 'Production for IT in sector 2'));

% Test 3: Partial indexing - tag subset of equations
m3 = modBuilder();
m3.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3, 4});
m3.parameter('A_$1', 1.0, {1, 2, 3, 4});
m3.exogenous('K_$1', 1.0, {1, 2, 3, 4});

% Tag only sectors 1 and 3
m3.tag('Y_$1', 'desc', 'Production function for sector $1', {1, 3});

% Verify only Y_1 and Y_3 have tags
assert(strcmp(m3.tags.Y_1.desc, 'Production function for sector 1'));
assert(strcmp(m3.tags.Y_3.desc, 'Production function for sector 3'));
assert(~isfield(m3.tags.Y_2, 'desc'));
assert(~isfield(m3.tags.Y_4, 'desc'));

% Test 4: Multiple tags with same equation pattern
m4 = modBuilder();
m4.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2});
m4.parameter('A_$1', 1.0, {1, 2});
m4.exogenous('K_$1', 1.0, {1, 2});

% Add multiple tags
m4.tag('Y_$1', 'desc', 'Production function for sector $1', {1, 2});
m4.tag('Y_$1', 'category', 'production', {1, 2});  % Note: tagname not indexed

% Verify both tags exist
assert(strcmp(m4.tags.Y_1.desc, 'Production function for sector 1'));
assert(strcmp(m4.tags.Y_2.desc, 'Production function for sector 2'));
assert(strcmp(m4.tags.Y_1.category, 'production'));
assert(strcmp(m4.tags.Y_2.category, 'production'));

% Test 5: Write model with tags and verify output
m5 = modBuilder();
m5.add('Y_$1', 'Y_$1 = A_$1*K_$1^alpha', {1, 2});
m5.parameter('A_$1', 1.0, {1, 2});
m5.parameter('alpha', 0.33);
m5.exogenous('K_$1', 1.0, {1, 2});
m5.tag('Y_$1', 'desc', 'Production function for sector $1', {1, 2});

m5.write('t01');

[b, diff] = modiff('t01.mod', 't01.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
end

delete t01.mod

fprintf('tag/t01.m: All tests passed\n');
