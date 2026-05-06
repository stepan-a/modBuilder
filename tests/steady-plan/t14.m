% steady_plan: joint AR closed via Cramer's rule.
% The two-equation simultaneous SCC {a, b} is linear in (a, b), so ast.linearise_system
% extracts (A, b) and ast.solve_linear_system produces the closed forms.

addpath ../utils

m = modBuilder();
m.add('a', 'a = rho*a(-1) + tau*b(-1) + e');
m.add('b', 'b = tau*a(-1) + rho*b(-1) + u');
m.parameter('rho', 0.5);
m.parameter('tau', 0.1);
m.exogenous('e', 1);
m.exogenous('u', 2);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 SCC, got %d.', numel(plan)), end
if ~strcmp(plan(1).kind, 'simultaneous'), error('Expected simultaneous block, got %s.', plan(1).kind), end
if numel(plan(1).closed_form) ~= 2
    error('Expected 2 closed forms, got %d.', numel(plan(1).closed_form))
end

% Verify each closed form numerically using ast.eval.
values = struct('rho', 0.5, 'tau', 0.1, 'e', 1, 'u', 2);
expected = struct('a', 0.7/0.24, 'b', 1.1/0.24);
for j = 1:2
    cf = plan(1).closed_form(j);
    val = ast(cf.expr).eval(values);
    if abs(val - expected.(cf.var)) > 1e-10
        error('Closed form for %s: got %g, expected %g.', cf.var, val, expected.(cf.var))
    end
end

% apply_steady_plan should write both closed forms.
m.apply_steady_plan();
if size(m.steady_state, 1) ~= 2
    error('Expected 2 steady-state entries, got %d.', size(m.steady_state, 1))
end

fprintf('t14.m: joint AR Cramer closure + apply_steady_plan OK\n');
