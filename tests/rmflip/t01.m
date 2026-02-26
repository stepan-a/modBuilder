addpath ../utils

% Test rmflip method: basic usage

% Build a simple model where y appears in k's equation
m = modBuilder();
m.add('y', 'y = a*k');
m.add('k', 'k = (1-delta)*k(-1) + i + y');
m.parameter('a', 0.33);
m.parameter('delta', 0.025);
m.exogenous('i', 0);

% Verify initial state
if m.size('endogenous') ~= 2
    error('Initial model should have 2 endogenous variables')
end

if ~m.isendogenous('y')
    error('y should be endogenous initially')
end

if ~m.isendogenous('k')
    error('k should be endogenous initially')
end

% Remove y's equation, make k exogenous instead
m.rmflip('y', 'k');

% y should remain endogenous (now determined by k's former equation)
if ~m.isendogenous('y')
    error('y should be endogenous after rmflip')
end

% k should now be exogenous
if ~m.isexogenous('k')
    error('k should be exogenous after rmflip')
end

% Only one equation should remain (named y, with k's old expression)
if m.size('endogenous') ~= 1
    error('Model should have 1 endogenous variable after rmflip')
end

if ~any(strcmp(m.equations(:,1), 'y'))
    error('Equation should be named y after rmflip')
end

if any(strcmp(m.equations(:,1), 'k'))
    error('Equation k should no longer exist after rmflip')
end

fprintf('t01.m: All tests passed\n');
