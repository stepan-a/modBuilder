addpath ../utils

% Test merge_parameters helper: common parameters with precedence rules
%
% Tests that when two models share parameters:
% - If both are calibrated, p's value takes precedence
% - If only one is calibrated, that value is used
% - Parameter metadata (long_name, tex_name) follows the calibration

% Model 1 with parameters
m1 = modBuilder();
m1.add('k', 'k = alpha*k(-1) + beta*e + gamma');
m1.parameter('alpha', 0.3);  % Common, calibrated in both
m1.parameter('beta', NaN);   % Common, only calibrated in m1 (implicitly by add)
m1.parameter('gamma', 0.7, 'long_name', 'Gamma param'); % Only in m1
m1.exogenous('e', 0);

% Model 2 with overlapping parameters
m2 = modBuilder();
m2.add('y', 'y = alpha*y(-1) + beta*delta*u');
m2.parameter('alpha', 0.5);  % Common, calibrated in both (should win)
m2.parameter('beta', 0.9);   % Common, only calibrated in m2 (should win)
m2.parameter('delta', 0.2, 'long_name', 'Delta param'); % Only in m2
m2.exogenous('u', 0);

% Merge models
merged = m1.merge(m2);

% Verify common parameter: m2 takes precedence when both calibrated
alpha_idx = find(strcmp(merged.params(:,1), 'alpha'));
if isempty(alpha_idx)
    error('Merged model missing common parameter alpha');
end
if merged.params{alpha_idx, 2} ~= 0.5
    error('Common parameter alpha should have value 0.5 from m2, got %f', merged.params{alpha_idx, 2});
end

% Verify common parameter: m2's calibration used when m1 has NaN
beta_idx = find(strcmp(merged.params(:,1), 'beta'));
if isempty(beta_idx)
    error('Merged model missing common parameter beta');
end
if merged.params{beta_idx, 2} ~= 0.9
    error('Common parameter beta should have value 0.9 from m2, got %f', merged.params{beta_idx, 2});
end

% Verify m1-only parameter
gamma_idx = find(strcmp(merged.params(:,1), 'gamma'));
if isempty(gamma_idx)
    error('Merged model missing m1-only parameter gamma');
end
if merged.params{gamma_idx, 2} ~= 0.7
    error('Parameter gamma should have value 0.7, got %f', merged.params{gamma_idx, 2});
end
if ~strcmp(merged.params{gamma_idx, 3}, 'Gamma param')
    error('Parameter gamma should have long_name "Gamma param"');
end

% Verify m2-only parameter
delta_idx = find(strcmp(merged.params(:,1), 'delta'));
if isempty(delta_idx)
    error('Merged model missing m2-only parameter delta');
end
if merged.params{delta_idx, 2} ~= 0.2
    error('Parameter delta should have value 0.2, got %f', merged.params{delta_idx, 2});
end
if ~strcmp(merged.params{delta_idx, 3}, 'Delta param')
    error('Parameter delta should have long_name "Delta param"');
end

% Verify total parameter count
expected_count = 4; % alpha, beta, gamma, delta
actual_count = size(merged.params, 1);
if actual_count ~= expected_count
    error('Expected %d parameters, got %d', expected_count, actual_count);
end
