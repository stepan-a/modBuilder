addpath ../utils
m = modBuilder();
m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
m.parameter('alpha', 0.36);
m.parameter('delta', 0.025);
m.exogenous('k', 10);

% Set initial guesses
m.endogenous('y', 1);
m.endogenous('c', 1);

m.solve_system({'y', 'c'}, {'y', 'c'});

% Check: y = 10^0.36, c = y - 0.025*10
ytrue = 10^0.36;
ctrue = ytrue - 0.025*10;
if abs(m.y - ytrue) > 1e-6 || abs(m.c - ctrue) > 1e-6
    error('solve_system produced wrong values')
end
