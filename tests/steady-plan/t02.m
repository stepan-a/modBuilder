% steady_plan: single equation, no self-reference: trivial block.

m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 1);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 block, got %d.', numel(plan)), end
if ~strcmp(plan(1).kind, 'trivial'), error('Expected trivial block, got %s.', plan(1).kind), end
if ~isequal(plan(1).vars, {'y'}), error('Expected vars = {y}.'), end
if ~isempty(plan(1).deps), error('Expected no endo deps.'), end
if ~isequal(sort(plan(1).extdeps), sort({'alpha', 'x'}))
    error('Expected external constants {alpha, x}, got {%s}.', strjoin(plan(1).extdeps, ', '))
end

fprintf('t02.m: trivial single block OK\n');
