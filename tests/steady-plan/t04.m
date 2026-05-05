% Tier 1 — two equations in a recursive chain: AR(1) for a, then y depending on a.
% Expected order: a (self-recursive, no endo deps) before y (trivial, depends on a).

m = modBuilder();
m.add('y', 'y = exp(a)*k^alpha');
m.add('a', 'a = rho*a(-1) + e');
m.parameter('alpha', 0.36);
m.parameter('rho', 0.95);
m.exogenous('e', 0);
m.exogenous('k', 1);

plan = m.steady_plan();

if numel(plan) ~= 2, error('Expected 2 blocks, got %d.', numel(plan)), end

% a must come first (no endo deps; y depends on a).
if ~isequal(plan(1).vars, {'a'}), error('Block 1 should be {a}, got {%s}.', strjoin(plan(1).vars, ', ')), end
if ~strcmp(plan(1).kind, 'self-recursive'), error('Block 1 kind should be self-recursive.'), end
if ~isempty(plan(1).deps), error('Block 1 should have no endo deps.'), end

if ~isequal(plan(2).vars, {'y'}), error('Block 2 should be {y}, got {%s}.', strjoin(plan(2).vars, ', ')), end
if ~strcmp(plan(2).kind, 'trivial'), error('Block 2 kind should be trivial.'), end
if ~isequal(plan(2).deps, {'a'}), error('Block 2 should depend on {a}.'), end

fprintf('t04.m: recursive chain OK\n');
