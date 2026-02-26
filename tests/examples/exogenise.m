% Test examples from exogenise method documentation

addpath ../utils

% Example 1: Make k exogenous by dropping y's equation
m = modBuilder();
m.add('y', 'y = a*k');
m.add('k', 'k = (1-delta)*k(-1) + i + y');
m.parameter('a', 0.33);
m.parameter('delta', 0.025);
m.exogenous('i', 0);

% Verify initial state
if ~m.isendogenous('y')
    error('y should be endogenous initially')
end
if ~m.isendogenous('k')
    error('k should be endogenous initially')
end

% Make k exogenous by dropping y's equation
m.exogenise('k', 'y');
% Equivalent to m.rmflip('y', 'k')

% Verify result
if ~m.isendogenous('y')
    error('y should be endogenous after exogenise')
end
if ~m.isexogenous('k')
    error('k should be exogenous after exogenise')
end
if m.size('endogenous') ~= 1
    error('Model should have 1 endogenous variable after exogenise')
end

fprintf('Example 1 passed: Make k exogenous by dropping y''s equation\n');

fprintf('exogenise.m: All tests passed\n');
