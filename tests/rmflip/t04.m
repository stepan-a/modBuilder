addpath ../utils

% Test rmflip with implicit loops

% Build model with indexed variables
m = modBuilder();
m.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
m.add('K_$1', 'K_$1 = (1-delta)*K_$1(-1) + I_$1 + Y_$1', {1, 2, 3});
m.parameter('A_$1', 1.0, {1, 2, 3});
m.parameter('delta', 0.025);
m.exogenous('I_$1', 0, {1, 2, 3});

% Verify initial state
if m.size('endogenous') ~= 6
    error('Initial model should have 6 endogenous variables')
end

% rmflip Y_$1 and K_$1 for indices 1 and 3 only
m.rmflip('Y_$1', 'K_$1', {1, 3});

% Y_1 and Y_3 should remain endogenous
if ~m.isendogenous('Y_1')
    error('Y_1 should be endogenous after rmflip')
end

if ~m.isendogenous('Y_3')
    error('Y_3 should be endogenous after rmflip')
end

% K_1 and K_3 should now be exogenous
if ~m.isexogenous('K_1')
    error('K_1 should be exogenous after rmflip')
end

if ~m.isexogenous('K_3')
    error('K_3 should be exogenous after rmflip')
end

% Y_2 and K_2 should be unchanged
if ~m.isendogenous('Y_2')
    error('Y_2 should remain endogenous')
end

if ~m.isendogenous('K_2')
    error('K_2 should remain endogenous')
end

% Should have 4 endogenous variables now (Y_1, Y_3, Y_2, K_2)
if m.size('endogenous') ~= 4
    error('Model should have 4 endogenous variables after rmflip, got %d', m.size('endogenous'))
end

fprintf('t04.m: All tests passed\n');
