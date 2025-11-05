% Test examples from flip method documentation

addpath ../utils

% Example 1: Simple flip
m = modBuilder();
m.add('y', 'y = a*k');
m.parameter('a', 0.33);
m.exogenous('k', 1.0);

% Verify initial state
if ~m.isendogenous('y')
    error('y should be endogenous initially')
end
if ~m.isexogenous('k')
    error('k should be exogenous initially')
end

% k becomes endogenous, y becomes exogenous
m.flip('y', 'k');

% Verify flip occurred
if ~m.isendogenous('k')
    error('k should be endogenous after flip')
end
if ~m.isexogenous('y')
    error('y should be exogenous after flip')
end

fprintf('Example 1 passed: Simple flip\n');

% Example 2: Implicit loop - flip multiple pairs
m2 = modBuilder();
m2.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
m2.parameter('A_$1', 1.0, {1, 2, 3});
m2.exogenous('K_$1', 1.0, {1, 2, 3});

% Verify initial state
if ~m2.isendogenous('Y_1')
    error('Y_1 should be endogenous initially')
end
if ~m2.isendogenous('Y_3')
    error('Y_3 should be endogenous initially')
end

% Flips Y_1↔K_1 and Y_3↔K_3
m2.flip('Y_$1', 'K_$1', {1, 3});

% Verify flips
if ~m2.isendogenous('K_1')
    error('K_1 should be endogenous after flip')
end
if ~m2.isendogenous('K_3')
    error('K_3 should be endogenous after flip')
end
if ~m2.isexogenous('Y_1')
    error('Y_1 should be exogenous after flip')
end
if ~m2.isexogenous('Y_3')
    error('Y_3 should be exogenous after flip')
end

% Y_2 should remain endogenous
if ~m2.isendogenous('Y_2')
    error('Y_2 should remain endogenous (not flipped)')
end

fprintf('Example 2 passed: Implicit loop - flip multiple pairs\n');

% Example 3: Multiple indices
m3 = modBuilder();
Countries = {'FR', 'DE'};
Sectors = {1, 2};
m3.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
m3.parameter('A_$1_$2', 1.0, Countries, Sectors);
m3.exogenous('K_$1_$2', 1.0, Countries, Sectors);

% Verify initial state
if ~m3.isendogenous('Y_FR_1')
    error('Y_FR_1 should be endogenous initially')
end
if ~m3.isendogenous('Y_FR_2')
    error('Y_FR_2 should be endogenous initially')
end

% Flips Y_FR_1↔K_FR_1 and Y_FR_2↔K_FR_2
m3.flip('Y_$1_$2', 'K_$1_$2', {'FR'}, {1, 2});

% Verify flips
if ~m3.isendogenous('K_FR_1')
    error('K_FR_1 should be endogenous after flip')
end
if ~m3.isendogenous('K_FR_2')
    error('K_FR_2 should be endogenous after flip')
end
if ~m3.isexogenous('Y_FR_1')
    error('Y_FR_1 should be exogenous after flip')
end
if ~m3.isexogenous('Y_FR_2')
    error('Y_FR_2 should be exogenous after flip')
end

% German variables should remain unchanged
if ~m3.isendogenous('Y_DE_1')
    error('Y_DE_1 should remain endogenous (not flipped)')
end
if ~m3.isendogenous('Y_DE_2')
    error('Y_DE_2 should remain endogenous (not flipped)')
end

fprintf('Example 3 passed: Multiple indices\n');

fprintf('flip.m: All tests passed\n');
