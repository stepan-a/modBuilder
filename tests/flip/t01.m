addpath ../utils

% Test flip method: basic flip without implicit loops (backward compatibility)

% Build a simple model
m = modBuilder();
m.add('y', 'y = a*k');
m.parameter('a', 0.33);
m.exogenous('k', 1.0);

% Verify initial state
if m.size('endogenous') ~= 1
    error('Initial model should have 1 endogenous variable')
end

if ~m.isendogenous('y')
    error('y should be endogenous initially')
end

if ~m.isexogenous('k')
    error('k should be exogenous initially')
end

% Flip y and k
m.flip('y', 'k');

% Verify flip occurred
if m.size('endogenous') ~= 1
    error('Model should still have 1 endogenous variable after flip')
end

if ~m.isendogenous('k')
    error('k should be endogenous after flip')
end

if ~m.isexogenous('y')
    error('y should be exogenous after flip')
end

% Check that equation name was updated
if ~any(strcmp(m.equations(:,1), 'k'))
    error('Equation should now be named k')
end

if any(strcmp(m.equations(:,1), 'y'))
    error('Equation should no longer be named y')
end

fprintf('t01.m: All tests passed\n');
