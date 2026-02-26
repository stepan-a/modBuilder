addpath ../utils

% Test checksteady() error: unknown symbol in expression

m = modBuilder();

m.add('y', 'y = alpha*k');
m.parameter('alpha', 0.36);
m.exogenous('k', 1.0);

% Expression references 'foo' which is not a known symbol
m.steady('y', 'alpha*foo');

try
    m.checksteady();
    error('Should have thrown an error for unknown symbol')
catch e
    if ~contains(e.message, 'Unknown symbol "foo"')
        error('Wrong error message: %s', e.message)
    end
end

fprintf('t11.m: All tests passed\n');
