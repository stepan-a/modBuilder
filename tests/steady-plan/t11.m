% apply_steady_plan writes closed forms into o.steady_state.

addpath ../utils

m = modBuilder();
m.add('a', 'a = rho*a(-1) + e');
m.add('y', 'y = exp(a)*k^alpha');
m.parameter('rho', 0.95);
m.parameter('alpha', 0.36);
m.exogenous('e', 0);
m.exogenous('k', 1);

m.apply_steady_plan();

% After applying, steady_state must contain entries for both a and y.
if size(m.steady_state, 1) ~= 2
    error('Expected 2 steady-state entries, got %d.', size(m.steady_state, 1))
end

% Look up entry for a.
idx_a = find(strcmp(m.steady_state(:, 1), 'a'));
if isempty(idx_a), error('Missing steady-state entry for a.'), end
expr_a = ast(m.steady_state{idx_a, 2}).simplify();
if ~ast.ast_equal(expr_a, ast('e/(1-rho)').simplify())
    error('Steady state for a should be e/(1-rho), got %s.', m.steady_state{idx_a, 2})
end

% Look up entry for y; depends on a being already solved (trivial block).
idx_y = find(strcmp(m.steady_state(:, 1), 'y'));
if isempty(idx_y), error('Missing steady-state entry for y.'), end
expr_y = ast(m.steady_state{idx_y, 2}).simplify();
if ~ast.ast_equal(expr_y, ast('exp(a)*k^alpha').simplify())
    error('Steady state for y should be exp(a)*k^alpha, got %s.', m.steady_state{idx_y, 2})
end

% Idempotency: a second call should not duplicate entries.
m.apply_steady_plan();
if size(m.steady_state, 1) ~= 2
    error('apply_steady_plan should be idempotent; got %d entries after second call.', size(m.steady_state, 1))
end

fprintf('t11.m: apply_steady_plan writes and is idempotent OK\n');
