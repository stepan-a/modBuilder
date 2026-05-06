% steady_plan with calibration swap: rbc3's labour supply.
% After calibrate('h', 1/3, 'theta'), the four-variable Euler block reduces fully:
% iterated elimination resolves y, c, k (h is now constant), and the labour FOC
% (paired with theta after the swap) is linear in theta.

addpath ../utils

m = modBuilder();
m.add('a', 'a = rho*a(-1) + tau*b(-1) + e');
m.add('b', 'b = tau*a(-1) + rho*b(-1) + u');
m.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');
m.add('c', 'k = exp(b)*(y-c) + (1-deltak)*k(-1)');
m.add('h', 'c*theta*h^(1+psi) = (1-alpha)*y');
m.add('k', '1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/k + (1-deltak))');
m.parameter('alpha', 0.36);
m.parameter('rho', 0.95);
m.parameter('tau', 0.025);
m.parameter('beta', 0.99);
m.parameter('deltak', 0.025);
m.parameter('psi', 0);
m.parameter('theta', 2.95);
m.exogenous('e', 0);
m.exogenous('u', 0);

m.calibrate('h', 1/3, 'theta');

plan = m.steady_plan();

% After the swap there should be three SCCs: {a, b}, {y, c, k}, {theta}.
if numel(plan) ~= 3
    error('Expected 3 SCCs after swap, got %d.', numel(plan))
end

% Block 3 (theta) must be fully closed.
b3 = plan(3);
if ~isequal(b3.vars, {'theta'}), error('Block 3 should be {theta}, got {%s}.', strjoin(b3.vars, ', ')), end
if numel(b3.closed_form) ~= 1, error('theta should have a closed form.'), end

% Block 2 ({y, c, k}) must be fully closed (h is calibrated, no longer in this block).
b2 = plan(2);
resolved_b2 = {b2.closed_form.var};
if ~isequal(sort(resolved_b2), sort({'c', 'k', 'y'}))
    error('Block 2 should resolve all of {y, c, k}, got {%s}.', strjoin(resolved_b2, ', '))
end

% apply_steady_plan must write a calibration anchor for h plus the closed forms.
m.apply_steady_plan();
% Expect entries: h (calibration anchor) + 6 closed forms (a, b, y, c, k, theta) = 7.
if size(m.steady_state, 1) ~= 7
    error('Expected 7 steady-state entries, got %d.', size(m.steady_state, 1))
end

% Verify the h anchor is 1/3.
idx_h = find(strcmp(m.steady_state(:, 1), 'h'));
if isempty(idx_h), error('Calibration anchor for h is missing.'), end
if abs(str2double(m.steady_state{idx_h, 2}) - 1/3) > 1e-10
    error('h anchor expected 1/3, got %s.', m.steady_state{idx_h, 2})
end

% Verify checksteady accepts the result and produces a valid topological order.
sorted = m.checksteady();
if numel(sorted) ~= 7, error('checksteady should sort 7 entries.'), end
% h must precede theta in the order (theta's expression references h).
pos_h = find(strcmp(sorted, 'h'));
pos_theta = find(strcmp(sorted, 'theta'));
if pos_h > pos_theta, error('checksteady ordering: h must come before theta.'), end

fprintf('t20.m: rbc3 labour-supply calibration swap closes the steady state OK\n');
