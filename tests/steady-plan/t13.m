% steady_plan: productivity inversion via exp.
% y = exp(a)*k^alpha*h^(1-alpha), paired with a (with y, k, h calibrated).
% Closed form: a = log(y / (k^alpha * h^(1-alpha))).

addpath ../utils

m = modBuilder();
m.add('a', 'y = exp(a)*k^alpha*h^(1-alpha)');
m.parameter('alpha', 0.36);
m.exogenous('y', 1);
m.exogenous('k', 1);
m.exogenous('h', 0.333);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 block.'), end
if isempty(plan(1).closed_form)
    error('Invertible-call recogniser should close the production function for a (exp inversion).')
end

rhs_tree = ast(plan(1).closed_form.expr).simplify();
expected = ast('log(y / (k^alpha * h^(1-alpha)))').simplify();
if ~ast.ast_equal(rhs_tree, expected)
    error('Expected closed form log(y / (k^alpha * h^(1-alpha))), got %s.', plan(1).closed_form.expr)
end

fprintf('t13.m: exp inversion OK\n');
