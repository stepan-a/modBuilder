% Tier 1 — single AR(1) equation: self-recursive block (the variable appears at a lag in
% its own equation, so the static form references the variable on both sides).

m = modBuilder();
m.add('a', 'a = rho*a(-1) + e');
m.parameter('rho', 0.95);
m.exogenous('e', 0);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 block, got %d.', numel(plan)), end
if ~strcmp(plan(1).kind, 'self-recursive')
    error('Expected self-recursive block, got %s.', plan(1).kind)
end
if ~isequal(plan(1).vars, {'a'}), error('Expected vars = {a}.'), end

fprintf('t03.m: self-recursive AR(1) block OK\n');
