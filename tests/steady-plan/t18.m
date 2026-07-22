% steady_plan: FULL closure of rbc3's four-variable Euler block. The labour FOC
% after substitution has h appearing with multiple exponents (h^(1+psi),
% h^(1-alpha) and the h nested in a power-of-product via the substituted k
% expression); the expansion tier of the iterated elimination distributes the
% powers over the products, collects h into a single monomial, and the whole
% block closes analytically.

addpath ../utils

m = modBuilder();
m.add('a', 'a = rho*a(-1) + tau*b(-1) + e');
m.add('b', 'b = tau*a(-1) + rho*b(-1) + u');
m.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');
m.add('c', 'k = exp(b)*(y-c) + (1-deltak)*k(-1)');
m.add('h', 'c*theta*h^(1+psi) = (1-alpha)*y');
m.add('k', '1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/k + (1-deltak))');
m.parameter('alpha', 0.36);
m.parameter('rho', 0.95);
m.parameter('tau', 0.025);
m.parameter('beta', 0.99);
m.parameter('deltak', 0.025);
m.parameter('psi', 0);
m.parameter('theta', 2.95);
m.exogenous('e', 0);
m.exogenous('u', 0);

plan = m.steady_plan();

if numel(plan) ~= 2, error('Expected 2 SCCs.'), end

% Block 2 is the Euler block.
b2 = plan(2);
if ~isequal(sort(b2.vars), sort({'c', 'h', 'k', 'y'}))
    error('Block 2 vars wrong: %s', strjoin(b2.vars, ', '))
end

resolved = {b2.closed_form.var};
if numel(resolved) ~= 4
    error('Expected full closure of the Euler block, got %d/4 (missing {%s}).', numel(resolved), strjoin(setdiff(b2.vars, resolved), ', '))
end

% The closed forms must evaluate to an exact steady state (a = b = 0 at zero shocks).
vals = struct('alpha', 0.36, 'rho', 0.95, 'tau', 0.025, 'beta', 0.99, 'deltak', 0.025, 'psi', 0, 'theta', 2.95, 'e', 0, 'u', 0, 'a', 0, 'b', 0);
for j = 1:numel(b2.closed_form)
    vals.(b2.closed_form(j).var) = ast(b2.closed_form(j).expr).eval(vals);
end
r = [vals.y - exp(vals.a)*vals.k^vals.alpha*vals.h^(1-vals.alpha); vals.k - exp(vals.b)*(vals.y - vals.c) - (1-vals.deltak)*vals.k; vals.c*vals.theta*vals.h^(1+vals.psi) - (1-vals.alpha)*vals.y; 1/vals.beta - (vals.alpha*vals.y/vals.k + 1 - vals.deltak)];
if max(abs(r)) > 1e-9
    error('Closed forms do not solve the Euler block (max residual %g).', max(abs(r)))
end

fprintf('t18.m: rbc3 Euler block closes fully through the expansion tier OK\n');
