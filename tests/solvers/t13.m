% Test solve_system validation: unknown symbol
addpath ../utils
m = modBuilder();
m.add('y', 'y = x');
m.exogenous('x', 1);
m.endogenous('y', 1);

try
    m.solve_system({'y'}, {'z'});   % z doesn't exist
    error('Should have thrown')
catch e
    assert(contains(e.message, 'Unknown symbol'), ...
        'Expected "Unknown symbol" in error message, got: %s', e.message)
end
