addpath ../utils

% Test rm method: implicit loops with single indexed equation

% Build model with indexed equations
m = modBuilder();
m.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3, 4, 5});
m.parameter('A_$1', 1.0, {1, 2, 3, 4, 5});
m.exogenous('K_$1', 1.0, {1, 2, 3, 4, 5});

% Verify initial state
if m.size('endogenous') ~= 5
    error('Initial model should have 5 endogenous variables')
end

% Remove equations using implicit loop
m.rm('Y_$1', {1, 3, 5});

% Verify correct equations were removed
if m.size('endogenous') ~= 2
    error('Model should have 2 endogenous variables after removal')
end

% Check that Y_2 and Y_4 remain
if ~any(strcmp(m.equations(:,1), 'Y_2'))
    error('Equation Y_2 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'Y_4'))
    error('Equation Y_4 should still exist')
end

% Check that Y_1, Y_3, Y_5 were removed
if any(strcmp(m.equations(:,1), 'Y_1'))
    error('Equation Y_1 should be removed')
end

if any(strcmp(m.equations(:,1), 'Y_3'))
    error('Equation Y_3 should be removed')
end

if any(strcmp(m.equations(:,1), 'Y_5'))
    error('Equation Y_5 should be removed')
end

fprintf('t02.m: All tests passed\n');
