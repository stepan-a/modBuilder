addpath ../utils

% Test basic steady-state expressions: define expressions, write with steady_state_model=true

m = modBuilder();

m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
m.add('k', '1/beta = alpha*y(+1)/k + (1-delta)');
m.parameter('alpha', 0.36);
m.parameter('beta', 0.99);
m.parameter('delta', 0.025);

m.steady('k', '(alpha*beta/(1-beta*(1-delta)))^(1/(1-alpha))');
m.steady('y', 'k^alpha');
m.steady('c', 'y - delta*k');

m.write('t01', steady_state_model=true);

b = modiff('t01.mod', 't01.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete t01.mod
end

fprintf('t01.m: All tests passed\n');
