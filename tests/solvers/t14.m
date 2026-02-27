% Test solve_system solving for an exogenous variable
addpath ../utils
m = modBuilder();
m.add('y', 'y = alpha*k');
m.parameter('alpha', 0.36);
m.exogenous('k', 1);
m.endogenous('y', 3.6);

% Solve for k given y = 3.6 → k = 3.6/0.36 = 10
m.solve_system({'y'}, {'k'});

if abs(m.k - 10) > 1e-10
    error('Exogenous solve: expected k=10, got k=%g', m.k)
end
