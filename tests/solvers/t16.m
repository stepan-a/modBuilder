% Test solve_system validation: symbol with no initial value
addpath ../utils
m = modBuilder();
m.add('y', 'y = k^alpha');
m.parameter('alpha', 0.36);
m.exogenous('k', 10);
% y has no value (NaN by default)

try
    m.solve_system({'y'}, {'y'});
    error('Should have thrown')
catch e
    assert(contains(e.message, 'no initial value'), ...
        'Expected "no initial value" in error message, got: %s', e.message)
end
