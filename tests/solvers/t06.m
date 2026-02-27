% Test solve_system on a simple linear 2×2 model
addpath ../utils
m = modBuilder();
m.add('y', 'y = alpha*k');
m.add('c', 'c = y - delta*k');
m.parameter('alpha', 0.36);
m.parameter('delta', 0.025);
m.exogenous('k', 10);

m.endogenous('y', 1);
m.endogenous('c', 1);

m.solve_system({'y', 'c'}, {'y', 'c'});

% y = 0.36*10 = 3.6, c = 3.6 - 0.025*10 = 3.35
if abs(m.y - 3.6) > 1e-10
    error('y is incorrect: expected 3.6, got %g', m.y)
end
if abs(m.c - 3.35) > 1e-10
    error('c is incorrect: expected 3.35, got %g', m.c)
end
