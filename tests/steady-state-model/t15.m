addpath ../utils

% Test parameter with steady expression: computed from steady-state values

m = modBuilder();

m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
m.add('k', '1/beta = alpha*y(+1)/k + (1-delta)');
m.add('w', 'w = labor_share*y');
m.parameter('alpha', 0.36);
m.parameter('beta', 0.99);
m.parameter('delta', 0.025);
m.parameter('labor_share', NaN);

m.steady('k', '(alpha*beta/(1-beta*(1-delta)))^(1/(1-alpha))');
m.steady('y', 'k^alpha');
m.steady('c', 'y - delta*k');
m.steady('labor_share', '1 - alpha*y/k');

m.write('t15', steady_state_model=true);

b = modiff('t15.mod', 't15.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete t15.mod
end

fprintf('t15.m: All tests passed\n');
