addpath ../utils

% Test steady() error: exogenous variable

m = modBuilder();

m.add('y', 'y = alpha*k');
m.parameter('alpha', 0.36);
m.exogenous('k', 1.0);

try
    m.steady('k', 'alpha');
    error('Should have thrown an error for exogenous variable')
catch e
    if ~contains(e.message, 'exogenous variable')
        error('Wrong error message: %s', e.message)
    end
end

% Test steady() error: unknown symbol
try
    m.steady('foo', 'alpha');
    error('Should have thrown an error for unknown symbol')
catch e
    if ~contains(e.message, 'not a known')
        error('Wrong error message: %s', e.message)
    end
end

fprintf('t13.m: All tests passed\n');
