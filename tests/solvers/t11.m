% Test solve_system for an exogenous variable
addpath ../utils
m = modBuilder();
m.add('y', 'y = k^alpha');
m.parameter('alpha', 0.36);
m.exogenous('k', 1);           % initial guess
m.endogenous('y', 10^0.36);    % target value

% Solve for k (exogenous) given known y
m.solve_system({'y'}, {'k'});

% Should find k = 10
if abs(m.k - 10) > 1e-6
    error('solve_system for exogenous: expected k=10, got k=%g', m.k)
end
