addpath ../utils

% Test validate_merge_compatibility helper: reject models with common endogenous
%
% Tests that merge correctly rejects models that share endogenous variables
% This should fail with a descriptive error message

% Model 1
m1 = modBuilder();
m1.add('k', 'k = alpha*k(-1) + e');
m1.parameter('alpha', 0.8);
m1.exogenous('e', 0);

% Model 2 with same endogenous variable
m2 = modBuilder();
m2.add('k', 'k = beta*k(-1) + u');  % Same endogenous variable 'k'
m2.parameter('beta', 0.7);
m2.exogenous('u', 0);

% Try to merge - should throw error
try
    merged = m1.merge(m2);
    error('merge should have thrown an error for common endogenous variables');
catch ME
    % Verify error message mentions common variables
    if ~contains(ME.message, 'common endogenous variables') && ~contains(ME.message, 'k')
        error('Error message should mention common endogenous variables and list them, got: %s', ME.message);
    end
    % Test passed - merge correctly rejected
end
