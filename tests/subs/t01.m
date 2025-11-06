addpath ../utils

% Test subs method: backward compatibility (simple substitution)

% Build a simple model
m = modBuilder();
m.add('y', 'y = alpha*k + beta*h');
m.parameter('alpha', 0.33);
m.parameter('beta', 0.67);
m.exogenous('k', 1.0);
m.exogenous('h', 1.0);

% Substitute alpha with gamma in equation y
m.subs('alpha', 'gamma', 'y');

% Verify substitution occurred
if ~strcmp(m{'y'}.equations{2}, 'y = gamma*k + beta*h')
    error('Substitution failed: expected "y = gamma*k + beta*h", got "%s"', m{'y'}.equations{2})
end

% Check that gamma is now a parameter (subs detected symbol and used rename via substitute)
if ~m.isparameter('gamma')
    error('Symbol gamma should be a parameter after substitution')
end

% Check that alpha no longer exists
if m.issymbol('alpha')
    error('Symbol alpha should no longer exist after substitution')
end

fprintf('t01.m: All tests passed\n');
