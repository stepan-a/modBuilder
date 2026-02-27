addpath ../utils
m = modBuilder();
m.add('k', '1/beta = alpha*y/k + (1-delta)');
m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
m.parameter('alpha', 0.36);
m.parameter('beta', 0.99);
m.parameter('delta', 0.025);

m.endogenous('k', 5);
m.endogenous('y', 1.5);
m.endogenous('c', 1);

m.solve_system({'k', 'y', 'c'}, {'k', 'y', 'c'});

% Verify residuals are near zero
r1 = abs(1/0.99 - 0.36*m.y/m.k - (1-0.025));
r2 = abs(m.y - m.k^0.36);
r3 = abs(m.c - m.y + 0.025*m.k);
if max([r1, r2, r3]) > 1e-6
    error('RBC steady state solve_system failed')
end
