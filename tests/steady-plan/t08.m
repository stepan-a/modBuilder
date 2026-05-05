% steady_plan: closed-form linear isolation in trivial blocks.

addpath ../utils

m = modBuilder();
m.add('y', 'y = alpha*x + beta');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.3);
m.exogenous('x', 1);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 block.'), end
if isempty(plan(1).closed_form), error('Closed form should be present for trivial linear block.'), end
if ~strcmp(plan(1).closed_form.var, 'y'), error('Closed-form var should be y.'), end

% Verify the closed form structurally: y = alpha*x + beta (the equation itself).
rhs_tree = ast(plan(1).closed_form.expr).simplify();
expected = ast('alpha*x + beta').simplify();
if ~ast.ast_equal(rhs_tree, expected)
    error('Expected closed form alpha*x + beta, got %s.', plan(1).closed_form.expr)
end

fprintf('t08.m: trivial linear isolation OK\n');
