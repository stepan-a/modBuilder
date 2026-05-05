% steady_plan: labour FOC closed via monomial isolation.
% c*theta*h^(1+psi) = (1-alpha)*y, paired with h.
% Closed form: h = ((1-alpha)*y / (c*theta))^(1/(1+psi)).

addpath ../utils

m = modBuilder();
m.add('h', 'c*theta*h^(1+psi) = (1-alpha)*y');
m.parameter('alpha', 0.36);
m.parameter('theta', 2.95);
m.parameter('psi', 0);
m.exogenous('c', 1);
m.exogenous('y', 1);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 block.'), end
if isempty(plan(1).closed_form)
    error('Monomial recogniser should close the labour FOC for h.')
end

rhs_tree = ast(plan(1).closed_form.expr).simplify();
expected = ast('((1-alpha)*y / (c*theta))^(1/(1+psi))').simplify();
if ~ast.ast_equal(rhs_tree, expected)
    error('Expected closed form ((1-alpha)*y/(c*theta))^(1/(1+psi)), got %s.', plan(1).closed_form.expr)
end

fprintf('t12.m: monomial labour FOC closure OK\n');
