addpath ../utils

% Test rmflip validation: error when eqname's variable does not appear in newexo's equation

% Build a model where y does NOT appear in k's equation
m = modBuilder();
m.add('y', 'y = a*x');
m.add('k', 'k = (1-delta)*k(-1) + i');
m.parameter('a', 0.33);
m.parameter('delta', 0.025);
m.exogenous('x', 1);
m.exogenous('i', 0);

% This should error because y does not appear in k's equation
try
    m.rmflip('y', 'k');
    error('rmflip should have thrown an error')
catch e
    if ~contains(e.message, 'does not appear in equation')
        error('Unexpected error message: %s', e.message)
    end
end

fprintf('t03.m: All tests passed\n');
