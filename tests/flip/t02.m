addpath ../utils

% Test flip method: implicit loop with single index

% Build model with indexed equations
m = modBuilder();
m.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3, 4});
m.parameter('A_$1', 1.0, {1, 2, 3, 4});
m.exogenous('K_$1', 1.0, {1, 2, 3, 4});

% Verify initial state
if m.size('endogenous') ~= 4
    error('Initial model should have 4 endogenous variables')
end

% Verify Y_1, Y_3 are endogenous and K_1, K_3 are exogenous
if ~m.isendogenous('Y_1')
    error('Y_1 should be endogenous initially')
end
if ~m.isendogenous('Y_3')
    error('Y_3 should be endogenous initially')
end
if ~m.isexogenous('K_1')
    error('K_1 should be exogenous initially')
end
if ~m.isexogenous('K_3')
    error('K_3 should be exogenous initially')
end

% Flip using implicit loop for indices 1 and 3
m.flip('Y_$1', 'K_$1', {1, 3});

% Verify flips occurred
if m.size('endogenous') ~= 4
    error('Model should still have 4 endogenous variables after flip')
end

% Check Y_1, Y_3 are now exogenous and K_1, K_3 are now endogenous
if ~m.isexogenous('Y_1')
    error('Y_1 should be exogenous after flip')
end
if ~m.isexogenous('Y_3')
    error('Y_3 should be exogenous after flip')
end
if ~m.isendogenous('K_1')
    error('K_1 should be endogenous after flip')
end
if ~m.isendogenous('K_3')
    error('K_3 should be endogenous after flip')
end

% Check that Y_2 and Y_4 remain endogenous (not flipped)
if ~m.isendogenous('Y_2')
    error('Y_2 should remain endogenous (not flipped)')
end
if ~m.isendogenous('Y_4')
    error('Y_4 should remain endogenous (not flipped)')
end
if ~m.isexogenous('K_2')
    error('K_2 should remain exogenous (not flipped)')
end
if ~m.isexogenous('K_4')
    error('K_4 should remain exogenous (not flipped)')
end

% Check equation names were updated
if ~any(strcmp(m.equations(:,1), 'K_1'))
    error('Equation K_1 should exist')
end
if ~any(strcmp(m.equations(:,1), 'K_3'))
    error('Equation K_3 should exist')
end
if any(strcmp(m.equations(:,1), 'Y_1'))
    error('Equation Y_1 should no longer exist')
end
if any(strcmp(m.equations(:,1), 'Y_3'))
    error('Equation Y_3 should no longer exist')
end

fprintf('t02.m: All tests passed\n');
