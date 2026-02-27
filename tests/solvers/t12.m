% Test solve_system validation: non-square system
addpath ../utils
m = modBuilder();
m.add('y', 'y = alpha*k');
m.add('c', 'c = y');
m.parameter('alpha', 0.5);
m.exogenous('k', 2);
m.endogenous('y', 1);
m.endogenous('c', 1);

try
    m.solve_system({'y', 'c'}, {'y'});   % 2 equations, 1 variable
    error('Should have thrown')
catch e
    assert(contains(e.message, 'square'), ...
        'Expected "square" in error message, got: %s', e.message)
end
