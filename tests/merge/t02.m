addpath ../utils

% Test merge_variables helper: exogenous to endogenous conversion
%
% Tests that when merging models:
% - Exogenous variable in one model can be endogenous in another
% - Type conversion happens automatically
% - Final model has correct variable types

% Model 1: y is endogenous, k is exogenous
m1 = modBuilder();
m1.add('y', 'y = alpha*y(-1) + beta*k');
m1.parameter('alpha', 0.8);
m1.parameter('beta', 0.3);
m1.exogenous('k', 0);  % k is exogenous in m1

% Model 2: k is endogenous, y is exogenous
m2 = modBuilder();
m2.add('k', 'k = gamma*k(-1) + delta*y');
m2.parameter('gamma', 0.7);
m2.parameter('delta', 0.2);
m2.exogenous('y', 0);  % y is exogenous in m2

% Merge models
merged = m1.merge(m2);

% Verify both are now endogenous
endo_names = merged.var(:,1);
if ~ismember('y', endo_names)
    error('Variable y should be endogenous in merged model');
end
if ~ismember('k', endo_names)
    error('Variable k should be endogenous in merged model');
end

% Verify neither is exogenous
exo_names = merged.varexo(:,1);
if ismember('y', exo_names)
    error('Variable y should not be exogenous in merged model');
end
if ismember('k', exo_names)
    error('Variable k should not be exogenous in merged model');
end

% Verify endogenous count (should be exactly 2: y and k)
if size(merged.var, 1) ~= 2
    error('Expected 2 endogenous variables, got %d', size(merged.var, 1));
end

% Verify exogenous count (should be 0 - all converted)
if size(merged.varexo, 1) ~= 0
    error('Expected 0 exogenous variables, got %d', size(merged.varexo, 1));
end

% Verify equations count (should be 2)
if size(merged.equations, 1) ~= 2
    error('Expected 2 equations, got %d', size(merged.equations, 1));
end
