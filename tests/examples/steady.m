% Test examples from steady method documentation

addpath ../utils

% Example 1: Basic steady-state expressions
m = modBuilder();
m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
m.add('k', '1/beta = alpha*y(+1)/k + (1-delta)');
m.parameter('alpha', 0.36);
m.parameter('beta', 0.99);
m.parameter('delta', 0.025);

% Define analytical steady-state expressions
m.steady('k', '(alpha*beta/(1-beta*(1-delta)))^(1/(1-alpha))');
m.steady('y', 'k^alpha');
m.steady('c', 'y - delta*k');

% Verify expressions were stored
if size(m.steady_state, 1) ~= 3
    error('Should have 3 steady-state expressions')
end

fprintf('Example 1 passed: Basic steady-state expressions\n');

% Example 2: Parameter computed from steady-state values
m.add('w', 'w = labor_share*y');
m.parameter('labor_share', NaN);
m.steady('labor_share', '1 - alpha*y/k');

if size(m.steady_state, 1) ~= 4
    error('Should have 4 steady-state expressions after adding parameter')
end

fprintf('Example 2 passed: Parameter computed from steady-state values\n');

% Example 3: Implicit loops
m2 = modBuilder();
m2.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
m2.parameter('A_$1', 1.0, {1, 2, 3});
m2.exogenous('K_$1', 1.0, {1, 2, 3});
m2.steady('Y_$1', 'A_$1*K_$1', {1, 2, 3});

if size(m2.steady_state, 1) ~= 3
    error('Implicit loop should create 3 steady-state expressions')
end

fprintf('Example 3 passed: Implicit loops\n');

fprintf('steady.m: All tests passed\n');
