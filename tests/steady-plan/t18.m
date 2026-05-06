% steady_plan: partial closure on rbc3's four-variable Euler block. The iterated
% elimination resolves y, k, c, but the labour FOC after substitution has h
% appearing with multiple exponents (h^(1+psi), h^(1-alpha) and the h that comes
% in via the substituted k expression), so no recogniser fires for h. The plan
% reports the residual {h} explicitly.

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
residual = setdiff(b2.vars, resolved);
if numel(residual) ~= 1 || ~strcmp(residual{1}, 'h')
    error('Expected residual {h}, got {%s}.', strjoin(residual, ', '))
end

% Three of the four vars must be resolved.
if numel(resolved) ~= 3
    error('Expected 3 resolved vars, got %d.', numel(resolved))
end

fprintf('t18.m: rbc3 Euler block: 3 of 4 vars resolved, residual {h} reported OK\n');
