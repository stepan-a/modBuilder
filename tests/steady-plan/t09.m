% steady_plan: closed-form linear isolation in self-recursive AR(1) block:
% a = rho*a(-1) + e  must collapse to a = e/(1-rho).

addpath ../utils

m = modBuilder();
m.add('a', 'a = rho*a(-1) + e');
m.parameter('rho', 0.95);
m.exogenous('e', 0);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 block.'), end
if isempty(plan(1).closed_form), error('Closed form should be present for AR(1) self-recursive block.'), end

rhs_tree = ast(plan(1).closed_form.expr).simplify();
expected = ast('e/(1-rho)').simplify();
if ~ast.ast_equal(rhs_tree, expected)
    error('Expected closed form e/(1-rho), got %s.', plan(1).closed_form.expr)
end

fprintf('t09.m: AR(1) linear isolation OK\n');
