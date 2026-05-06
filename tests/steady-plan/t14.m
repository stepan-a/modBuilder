% steady_plan: joint AR closed via Bareiss + back-substitution.
% The two-equation simultaneous SCC {a, b} is linear in (a, b); ast.linearise_system
% extracts (A, b) and steady_plan back-substitutes after triangulating, producing one
% var assignment per unknown. Each x_i references later-solved variables by name, so
% the rendered closed forms stay compact.

addpath ../utils

m = modBuilder();
m.add('a', 'a = rho*a(-1) + tau*b(-1) + e');
m.add('b', 'b = tau*a(-1) + rho*b(-1) + u');
m.parameter('rho', 0.5);
m.parameter('tau', 0.1);
m.exogenous('e', 1);
m.exogenous('u', 2);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 SCC.'), end
if ~strcmp(plan(1).kind, 'simultaneous'), error('Expected simultaneous block, got %s.', plan(1).kind), end

cf = plan(1).closed_form;
if numel(cf) ~= 2
    error('Expected 2 closed-form entries, got %d.', numel(cf))
end

% Evaluate the closed forms in order, accumulating values for the variables that have
% already been assigned (later x_i references earlier-solved x_j by name).
values = struct('rho', 0.5, 'tau', 0.1, 'e', 1, 'u', 2);
for j = 1:numel(cf)
    val = ast(cf(j).expr).eval(values);
    values.(cf(j).var) = val;
end
expected = struct('a', 0.7/0.24, 'b', 1.1/0.24);
for name = {'a', 'b'}
    if abs(values.(name{1}) - expected.(name{1})) > 1e-10
        error('Closed form for %s: got %g, expected %g.', name{1}, values.(name{1}), expected.(name{1}))
    end
end

% apply_steady_plan must write both var assignments into o.steady_state.
m.apply_steady_plan();
if size(m.steady_state, 1) ~= 2
    error('Expected 2 steady-state entries, got %d.', size(m.steady_state, 1))
end

fprintf('t14.m: joint AR back-sub closure OK\n');
