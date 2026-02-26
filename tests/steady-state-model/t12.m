addpath ../utils

% Test checksteady() error: circular dependency

m = modBuilder();

m.add('y', 'y = alpha*k');
m.add('c', 'c = y - k');
m.parameter('alpha', 0.36);
m.exogenous('k', 1.0);

% Circular: y depends on c, c depends on y
m.steady('y', 'c + alpha*k');
m.steady('c', 'y - k');

try
    m.checksteady();
    error('Should have thrown an error for circular dependency')
catch e
    if ~contains(e.message, 'Circular dependency')
        error('Wrong error message: %s', e.message)
    end
end

fprintf('t12.m: All tests passed\n');
