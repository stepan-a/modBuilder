addpath ../utils

% Test exogenise method: variable-centric interface to rmflip

% Build the same model
m = modBuilder();
m.add('y', 'y = a*k');
m.add('k', 'k = (1-delta)*k(-1) + i + y');
m.parameter('a', 0.33);
m.parameter('delta', 0.025);
m.exogenous('i', 0);

% Make k exogenous by dropping y's equation (equivalent to rmflip('y','k'))
m.exogenise('k', 'y');

% y should remain endogenous
if ~m.isendogenous('y')
    error('y should be endogenous after exogenise')
end

% k should now be exogenous
if ~m.isexogenous('k')
    error('k should be exogenous after exogenise')
end

% Only one equation should remain
if m.size('endogenous') ~= 1
    error('Model should have 1 endogenous variable after exogenise')
end

if ~any(strcmp(m.equations(:,1), 'y'))
    error('Equation should be named y after exogenise')
end

if any(strcmp(m.equations(:,1), 'k'))
    error('Equation k should no longer exist after exogenise')
end

fprintf('t02.m: All tests passed\n');
