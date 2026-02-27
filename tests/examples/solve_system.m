% Test examples from solve_system method documentation

addpath ../utils

% Example 1: Solve for the RBC steady state
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
r1 = abs(1/m.beta - m.alpha*m.y/m.k - (1-m.delta));
r2 = abs(m.y - m.k^m.alpha);
r3 = abs(m.c - m.y + m.delta*m.k);
if max([r1, r2, r3]) > 1e-6
    error('RBC steady state residuals are too large')
end

fprintf('Example 1 passed: RBC steady state\n');

% Example 2: Solve for a parameter and an endogenous variable
m2 = modBuilder();
m2.add('y', 'y = k^alpha');
m2.add('c', 'c = y - delta*k');
m2.parameter('alpha', 0.5);
m2.parameter('delta', 0.025);
m2.exogenous('k', 4);

m2.endogenous('y', 2);
m2.endogenous('c', 1);

m2.solve_system({'y', 'c'}, {'alpha', 'c'});

% y = k^alpha → 2 = 4^alpha → alpha = 0.5
% c = y - delta*k → c = 2 - 0.025*4 = 1.9
if abs(m2.alpha - 0.5) > 1e-6
    error('Parameter alpha is wrong: expected 0.5, got %g', m2.alpha)
end
if abs(m2.c - 1.9) > 1e-6
    error('Endogenous c is wrong: expected 1.9, got %g', m2.c)
end

fprintf('Example 2 passed: Mixed parameter and endogenous solve\n');

% Example 3: Solve with custom tolerance
m3 = modBuilder();
m3.add('y', 'y = k^alpha');
m3.parameter('alpha', 0.36);
m3.exogenous('k', 10);
m3.endogenous('y', 1);

m3.solve_system({'y'}, {'y'}, 'tol', 1e-12);

if abs(m3.y - 10^0.36) > 1e-10
    error('Solve with tight tolerance failed')
end

fprintf('Example 3 passed: Custom tolerance\n');

fprintf('solve_system.m: All tests passed\n');
