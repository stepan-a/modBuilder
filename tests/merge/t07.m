addpath ../utils

% Test merge_parameters helper: metadata preservation
%
% Tests that when merging models:
% - long_name and tex_name are preserved correctly
% - Metadata follows parameter calibration (p's metadata takes precedence)

% Model 1 with metadata
m1 = modBuilder();
m1.add('y', 'y = alpha*y(-1) + beta*e + gamma');
m1.parameter('alpha', 0.3, 'long_name', 'Persistence parameter', 'texname', '\alpha_1');
m1.parameter('beta', NaN, 'long_name', 'Beta from m1', 'texname', '\beta_1');  % NaN calibration
m1.parameter('gamma', 0.7, 'long_name', 'Gamma parameter', 'texname', '\gamma');
m1.exogenous('e', 0);

% Model 2 with overlapping parameters and different metadata
m2 = modBuilder();
m2.add('k', 'k = alpha*k(-1) + beta*delta*u');
m2.parameter('alpha', 0.5, 'long_name', 'Alpha from m2', 'texname', '\alpha_2');  % Should win
m2.parameter('beta', 0.9, 'long_name', 'Beta from m2', 'texname', '\beta_2');   % Should win
m2.parameter('delta', 0.2, 'long_name', 'Delta parameter', 'texname', '\delta');
m2.exogenous('u', 0);

% Merge models
merged = m1.merge(m2);

% Test 1: Common parameter 'alpha' - m2 calibration and metadata should win
alpha_idx = find(strcmp(merged.params(:,1), 'alpha'));
if isempty(alpha_idx)
    error('Merged model missing parameter alpha');
end
if merged.params{alpha_idx, 2} ~= 0.5
    error('alpha should have value 0.5 from m2, got %f', merged.params{alpha_idx, 2});
end
if ~strcmp(merged.params{alpha_idx, 3}, 'Alpha from m2')
    error('alpha should have long_name from m2, got: %s', merged.params{alpha_idx, 3});
end
if ~strcmp(merged.params{alpha_idx, 4}, '\alpha_2')
    error('alpha should have tex_name from m2, got: %s', merged.params{alpha_idx, 4});
end

% Test 2: Common parameter 'beta' - m2 calibration and metadata should win (m1 has NaN)
beta_idx = find(strcmp(merged.params(:,1), 'beta'));
if isempty(beta_idx)
    error('Merged model missing parameter beta');
end
if merged.params{beta_idx, 2} ~= 0.9
    error('beta should have value 0.9 from m2, got %f', merged.params{beta_idx, 2});
end
if ~strcmp(merged.params{beta_idx, 3}, 'Beta from m2')
    error('beta should have long_name from m2, got: %s', merged.params{beta_idx, 3});
end
if ~strcmp(merged.params{beta_idx, 4}, '\beta_2')
    error('beta should have tex_name from m2, got: %s', merged.params{beta_idx, 4});
end

% Test 3: m1-only parameter 'gamma' - should preserve metadata
gamma_idx = find(strcmp(merged.params(:,1), 'gamma'));
if isempty(gamma_idx)
    error('Merged model missing parameter gamma');
end
if merged.params{gamma_idx, 2} ~= 0.7
    error('gamma should have value 0.7, got %f', merged.params{gamma_idx, 2});
end
if ~strcmp(merged.params{gamma_idx, 3}, 'Gamma parameter')
    error('gamma should preserve long_name, got: %s', merged.params{gamma_idx, 3});
end
if ~strcmp(merged.params{gamma_idx, 4}, '\gamma')
    error('gamma should preserve tex_name, got: %s', merged.params{gamma_idx, 4});
end

% Test 4: m2-only parameter 'delta' - should preserve metadata
delta_idx = find(strcmp(merged.params(:,1), 'delta'));
if isempty(delta_idx)
    error('Merged model missing parameter delta');
end
if merged.params{delta_idx, 2} ~= 0.2
    error('delta should have value 0.2, got %f', merged.params{delta_idx, 2});
end
if ~strcmp(merged.params{delta_idx, 3}, 'Delta parameter')
    error('delta should preserve long_name, got: %s', merged.params{delta_idx, 3});
end
if ~strcmp(merged.params{delta_idx, 4}, '\delta')
    error('delta should preserve tex_name, got: %s', merged.params{delta_idx, 4});
end
