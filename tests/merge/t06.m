addpath ../utils

% Test merge edge cases: empty and minimal models
%
% Tests that merging works correctly with:
% - Empty model with populated model
% - Minimal models (single equation, single parameter)

% Test 1: Merge populated model with empty model
m1 = modBuilder();
m1.add('y', 'y = alpha*y(-1) + e');
m1.parameter('alpha', 0.8);
m1.exogenous('e', 0);

m_empty = modBuilder();

merged1 = m1.merge(m_empty);

% Verify result is equivalent to m1
if size(merged1.var, 1) ~= 1 || ~strcmp(merged1.var{1,1}, 'y')
    error('Merging with empty model should preserve original endogenous variables');
end
if size(merged1.params, 1) ~= 1 || ~strcmp(merged1.params{1,1}, 'alpha')
    error('Merging with empty model should preserve original parameters');
end
if size(merged1.varexo, 1) ~= 1 || ~strcmp(merged1.varexo{1,1}, 'e')
    error('Merging with empty model should preserve original exogenous variables');
end
if size(merged1.equations, 1) ~= 1
    error('Merging with empty model should preserve original equations');
end

% Test 2: Merge empty model with populated model (reverse order)
merged2 = m_empty.merge(m1);

if size(merged2.var, 1) ~= 1 || ~strcmp(merged2.var{1,1}, 'y')
    error('Merging empty with populated should preserve endogenous variables');
end
if size(merged2.params, 1) ~= 1 || ~strcmp(merged2.params{1,1}, 'alpha')
    error('Merging empty with populated should preserve parameters');
end
if size(merged2.varexo, 1) ~= 1 || ~strcmp(merged2.varexo{1,1}, 'e')
    error('Merging empty with populated should preserve exogenous variables');
end

% Test 3: Merge two minimal models
min1 = modBuilder();
min1.add('x', 'x = a*x(-1)');
min1.parameter('a', 0.9);

min2 = modBuilder();
min2.add('z', 'z = b*z(-1)');
min2.parameter('b', 0.7);

merged_min = min1.merge(min2);

if size(merged_min.var, 1) ~= 2
    error('Expected 2 endogenous variables from minimal merge, got %d', size(merged_min.var, 1));
end
if size(merged_min.params, 1) ~= 2
    error('Expected 2 parameters from minimal merge, got %d', size(merged_min.params, 1));
end
if size(merged_min.equations, 1) ~= 2
    error('Expected 2 equations from minimal merge, got %d', size(merged_min.equations, 1));
end
if size(merged_min.varexo, 1) ~= 0
    error('Expected 0 exogenous variables from minimal merge, got %d', size(merged_min.varexo, 1));
end
