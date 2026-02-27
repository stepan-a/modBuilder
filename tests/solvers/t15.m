% Test solve_system with equation without = sign
addpath ../utils
m = modBuilder();
m.add('y', 'y - alpha*k');     % no = sign
m.parameter('alpha', 0.36);
m.exogenous('k', 10);
m.endogenous('y', 0);

% Solve: y - 0.36*10 = 0 → y = 3.6
m.solve_system({'y'}, {'y'});

if abs(m.y - 3.6) > 1e-10
    error('No-equals equation: expected y=3.6, got y=%g', m.y)
end
