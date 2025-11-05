% Test examples from rm method documentation

addpath ../utils

% Example 1: Remove multiple equations
m = modBuilder();
m.add('c', 'c = alpha*k');
m.add('y', 'y = k^alpha');
m.parameter('alpha', 0.33);
m.exogenous('k', 1.0);

% Verify initial state
if m.size('endogenous') ~= 2
    error('Initial model should have 2 endogenous variables')
end

% Remove multiple equations
m.rm('c', 'y');

% Verify all equations were removed
if m.size('endogenous') ~= 0
    error('Model should have 0 endogenous variables after removal')
end

if any(strcmp(m.equations(:,1), 'c'))
    error('Equation c should be removed')
end

if any(strcmp(m.equations(:,1), 'y'))
    error('Equation y should be removed')
end

fprintf('Example 1 passed: Remove multiple equations\n');

% Example 2: Remove indexed equations with implicit loop
m2 = modBuilder();
m2.add('eq$1', 'eq$1 = A$1*K$1', {1, 2, 3});
m2.parameter('A$1', 1.0, {1, 2, 3});
m2.exogenous('K$1', 1.0, {1, 2, 3});

% Verify initial state
if m2.size('endogenous') ~= 3
    error('Initial model should have 3 endogenous variables')
end

% Remove eq1, eq2, eq3
m2.rm('eq$1', {1, 2, 3});

% Verify all equations were removed
if m2.size('endogenous') ~= 0
    error('Model should have 0 endogenous variables after removal')
end

fprintf('Example 2 passed: Remove indexed equations with implicit loop\n');

% Example 3: Remove multiple indexed equations
m3 = modBuilder();
m3.add('eq$1', 'eq$1 = A$1*K$1', {1, 2});
m3.add('var$1', 'var$1 = B*eq$1', {1, 2});
m3.parameter('A$1', 1.0, {1, 2});
m3.parameter('B', 0.5);
m3.exogenous('K$1', 1.0, {1, 2});

% Verify initial state
if m3.size('endogenous') ~= 4
    error('Initial model should have 4 endogenous variables')
end

% Remove eq1, var1, eq2, var2
m3.rm('eq$1', 'var$1', {1, 2});

% Verify all equations were removed
if m3.size('endogenous') ~= 0
    error('Model should have 0 endogenous variables after removal')
end

fprintf('Example 3 passed: Remove multiple indexed equations\n');

fprintf('rm.m: All tests passed\n');
