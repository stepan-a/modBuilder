addpath ../utils

% Test rm method: implicit loops with multiple indices

% Build model with multiple indices
m = modBuilder();
Countries = {'FR', 'DE', 'IT'};
Sectors = {1, 2};
m.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
m.add('C_$1_$2', 'C_$1_$2 = alpha*Y_$1_$2', Countries, Sectors);
m.parameter('A_$1_$2', 1.0, Countries, Sectors);
m.parameter('alpha', 0.6);
m.exogenous('K_$1_$2', 1.0, Countries, Sectors);

% Verify initial state
if m.size('endogenous') ~= 12
    error('Initial model should have 12 endogenous variables (3 countries × 2 sectors × 2 equation types)')
end

% Remove only Y equations for one country using implicit loop
m.rm('Y_$1_$2', {'FR'}, {1, 2});

% Verify correct equations were removed
if m.size('endogenous') ~= 10
    error('Model should have 10 endogenous variables after removal')
end

% Check that German and Italian equations remain
if ~any(strcmp(m.equations(:,1), 'Y_DE_1'))
    error('Equation Y_DE_1 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'Y_DE_2'))
    error('Equation Y_DE_2 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'Y_IT_1'))
    error('Equation Y_IT_1 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'Y_IT_2'))
    error('Equation Y_IT_2 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'C_DE_1'))
    error('Equation C_DE_1 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'C_DE_2'))
    error('Equation C_DE_2 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'C_IT_1'))
    error('Equation C_IT_1 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'C_IT_2'))
    error('Equation C_IT_2 should still exist')
end

% Check that French equations were removed
if any(strcmp(m.equations(:,1), 'Y_FR_1'))
    error('Equation Y_FR_1 should be removed')
end

if any(strcmp(m.equations(:,1), 'Y_FR_2'))
    error('Equation Y_FR_2 should be removed')
end

% Check that French C equations still exist
if ~any(strcmp(m.equations(:,1), 'C_FR_1'))
    error('Equation C_FR_1 should still exist')
end

if ~any(strcmp(m.equations(:,1), 'C_FR_2'))
    error('Equation C_FR_2 should still exist')
end

% Check that removed Y_FR variables became exogenous (still used in C_FR equations)
if ~m.isexogenous('Y_FR_1')
    error('Variable Y_FR_1 should be exogenous after equation removal')
end

if ~m.isexogenous('Y_FR_2')
    error('Variable Y_FR_2 should be exogenous after equation removal')
end

fprintf('t04.m: All tests passed\n');
