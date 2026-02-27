addpath ../utils
m = modBuilder();
m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
m.parameter('alpha', 0.5);
m.parameter('delta', 0.025);
m.exogenous('k', 4);

% Solve for alpha (parameter) and c (endogenous) given target y = 2
m.endogenous('y', 2);
m.endogenous('c', 1);

m.solve_system({'y', 'c'}, {'alpha', 'c'});

% Check: y = k^alpha → 2 = 4^alpha → alpha = 0.5, c = 2 - 0.025*4 = 1.9
if abs(m.alpha - 0.5) > 1e-6
    error('solve_system: parameter alpha is wrong')
end
if abs(m.c - 1.9) > 1e-6
    error('solve_system: endogenous c is wrong')
end
