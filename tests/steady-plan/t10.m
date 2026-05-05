% Tier 2-A — non-linear single-variable equations are not closed by Phase 2.
% c*theta*h^(1+psi) = (1-alpha)*y is monomial (not linear) in h — Phase 2 leaves it open.

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
if ~isempty(plan(1).closed_form)
    error('Phase 2 should NOT close a monomial equation; got closed form %s.', plan(1).closed_form.expr)
end

fprintf('t10.m: non-linear equation correctly left unclosed by Phase 2 OK\n');
