addpath ../utils

% Test mixed: some variables with expressions, some with only numeric values

m = modBuilder();

m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
m.add('k', '1/beta = alpha*y(+1)/k + (1-delta)');
m.parameter('alpha', 0.36);
m.parameter('beta', 0.99);
m.parameter('delta', 0.025);

% Only define steady for y (k has no expression, used as a leaf constant with numeric value)
m.endogenous('k', 5.0);
m.steady('y', 'k^alpha');

m.write('t04', steady_state_model=true);

b = modiff('t04.mod', 't04.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete t04.mod
end

fprintf('t04.m: All tests passed\n');
