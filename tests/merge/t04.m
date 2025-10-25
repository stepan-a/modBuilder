addpath ../utils

% Test merge_variables helper: common exogenous variables
%
% Tests that when merging models:
% - Common exogenous variables are handled correctly
% - Calibration values are merged appropriately
% - No duplication occurs

% Model 1: exogenous variable 'e' with calibration 0.1
m1 = modBuilder();
m1.add('y', 'y = alpha*y(-1) + e');
m1.parameter('alpha', 0.8);
m1.exogenous('e', 0.1);

% Model 2: also has exogenous variable 'e' with different calibration 0.2
m2 = modBuilder();
m2.add('k', 'k = beta*k(-1) + e');
m2.parameter('beta', 0.7);
m2.exogenous('e', 0.2);  % m2's value should win (precedence)

% Merge models
merged = m1.merge(m2);

% Verify 'e' appears exactly once in exogenous list (deduplicated)
exo_names = merged.varexo(:,1);
e_count = sum(strcmp(exo_names, 'e'));
if e_count ~= 1
    error('Exogenous variable e should appear exactly once after deduplication, found %d occurrences', e_count);
end

% Verify that m2's calibration takes precedence for common exogenous 'e'
e_idx = find(strcmp(merged.varexo(:,1), 'e'));
if merged.varexo{e_idx, 2} ~= 0.2
    error('Common exogenous variable e should have value 0.2 from m2 (precedence), got %f', merged.varexo{e_idx, 2});
end

% Verify both endogenous variables are present
endo_names = merged.var(:,1);
if ~ismember('y', endo_names)
    error('Variable y should be endogenous in merged model');
end
if ~ismember('k', endo_names)
    error('Variable k should be endogenous in merged model');
end

% Verify counts (1 exogenous after deduplication)
if size(merged.varexo, 1) ~= 1
    error('Expected 1 exogenous variable after deduplication, got %d', size(merged.varexo, 1));
end

if size(merged.var, 1) ~= 2
    error('Expected 2 endogenous variables, got %d', size(merged.var, 1));
end

if size(merged.equations, 1) ~= 2
    error('Expected 2 equations, got %d', size(merged.equations, 1));
end
