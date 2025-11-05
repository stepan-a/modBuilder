addpath ../utils

% Test flip method: implicit loop with multiple indices

% Build model with multiple indices
Countries = {'FR', 'DE', 'IT'};
Sectors = {1, 2};
m = modBuilder();
m.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
m.parameter('A_$1_$2', 1.0, Countries, Sectors);
m.exogenous('K_$1_$2', 1.0, Countries, Sectors);

% Verify initial state
if m.size('endogenous') ~= 6
    error('Initial model should have 6 endogenous variables')
end

% Verify French variables are initially as expected
if ~m.isendogenous('Y_FR_1')
    error('Y_FR_1 should be endogenous initially')
end
if ~m.isendogenous('Y_FR_2')
    error('Y_FR_2 should be endogenous initially')
end
if ~m.isexogenous('K_FR_1')
    error('K_FR_1 should be exogenous initially')
end
if ~m.isexogenous('K_FR_2')
    error('K_FR_2 should be exogenous initially')
end

% Flip French variables only using implicit loop
m.flip('Y_$1_$2', 'K_$1_$2', {'FR'}, {1, 2});

% Verify flips occurred for French variables
if m.size('endogenous') ~= 6
    error('Model should still have 6 endogenous variables after flip')
end

if ~m.isexogenous('Y_FR_1')
    error('Y_FR_1 should be exogenous after flip')
end
if ~m.isexogenous('Y_FR_2')
    error('Y_FR_2 should be exogenous after flip')
end
if ~m.isendogenous('K_FR_1')
    error('K_FR_1 should be endogenous after flip')
end
if ~m.isendogenous('K_FR_2')
    error('K_FR_2 should be endogenous after flip')
end

% Verify German and Italian variables remain unchanged
if ~m.isendogenous('Y_DE_1')
    error('Y_DE_1 should remain endogenous (not flipped)')
end
if ~m.isendogenous('Y_DE_2')
    error('Y_DE_2 should remain endogenous (not flipped)')
end
if ~m.isendogenous('Y_IT_1')
    error('Y_IT_1 should remain endogenous (not flipped)')
end
if ~m.isendogenous('Y_IT_2')
    error('Y_IT_2 should remain endogenous (not flipped)')
end

% Check equation names
if ~any(strcmp(m.equations(:,1), 'K_FR_1'))
    error('Equation K_FR_1 should exist')
end
if ~any(strcmp(m.equations(:,1), 'K_FR_2'))
    error('Equation K_FR_2 should exist')
end
if any(strcmp(m.equations(:,1), 'Y_FR_1'))
    error('Equation Y_FR_1 should no longer exist')
end
if any(strcmp(m.equations(:,1), 'Y_FR_2'))
    error('Equation Y_FR_2 should no longer exist')
end

% German and Italian equations should still exist with Y names
if ~any(strcmp(m.equations(:,1), 'Y_DE_1'))
    error('Equation Y_DE_1 should still exist')
end
if ~any(strcmp(m.equations(:,1), 'Y_IT_2'))
    error('Equation Y_IT_2 should still exist')
end

fprintf('t03.m: All tests passed\n');
