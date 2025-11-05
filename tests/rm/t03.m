addpath ../utils

% Test rm method: implicit loops with multiple indexed equations

% Build model with multiple indexed equation types
m = modBuilder();
m.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
m.add('C_$1', 'C_$1 = alpha*Y_$1', {1, 2, 3});
m.add('I_$1', 'I_$1 = beta*Y_$1', {1, 2, 3});
m.parameter('A_$1', 1.0, {1, 2, 3});
m.parameter('alpha', 0.6);
m.parameter('beta', 0.3);
m.exogenous('K_$1', 1.0, {1, 2, 3});

% Verify initial state
if m.size('endogenous') ~= 9
    error('Initial model should have 9 endogenous variables')
end

% Remove multiple equation types with implicit loop
m.rm('Y_$1', 'C_$1', {1, 3});

% Verify correct equations were removed
if m.size('endogenous') ~= 5
    error('Model should have 5 endogenous variables after removal')
end

% Check that Y_2, C_2, and all I equations remain
if ~any(strcmp(m.equations(:,1), 'Y_2'))
    error('Equation Y_2 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'C_2'))
    error('Equation C_2 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'I_1'))
    error('Equation I_1 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'I_2'))
    error('Equation I_2 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'I_3'))
    error('Equation I_3 should still exist')
end

% Check that Y_1, Y_3, C_1, C_3 were removed
if any(strcmp(m.equations(:,1), 'Y_1'))
    error('Equation Y_1 should be removed')
end

if any(strcmp(m.equations(:,1), 'Y_3'))
    error('Equation Y_3 should be removed')
end

if any(strcmp(m.equations(:,1), 'C_1'))
    error('Equation C_1 should be removed')
end

if any(strcmp(m.equations(:,1), 'C_3'))
    error('Equation C_3 should be removed')
end

% Check that removed Y variables became exogenous (still used in I equations)
if ~m.isexogenous('Y_1')
    error('Variable Y_1 should be exogenous after equation removal')
end

if ~m.isexogenous('Y_3')
    error('Variable Y_3 should be exogenous after equation removal')
end

fprintf('t03.m: All tests passed\n');
