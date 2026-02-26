addpath ../utils

% Test topological ordering: call steady in wrong dependency order

m = modBuilder();

m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
m.add('k', '1/beta = alpha*y(+1)/k + (1-delta)');
m.parameter('alpha', 0.36);
m.parameter('beta', 0.99);
m.parameter('delta', 0.025);

% Define in wrong order: c depends on y and k, y depends on k
m.steady('c', 'y - delta*k');
m.steady('y', 'k^alpha');
m.steady('k', '(alpha*beta/(1-beta*(1-delta)))^(1/(1-alpha))');

m.write('t02', steady_state_model=true);

b = modiff('t02.mod', 't02.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete t02.mod
end

fprintf('t02.m: All tests passed\n');
