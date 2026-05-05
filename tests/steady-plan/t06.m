% Tier 1 — full rbc3 model: joint AR {a, b} plus the four-variable simultaneous block
% {y, c, h, k}. The plan should expose exactly those two SCCs in topological order.

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

if numel(plan) ~= 2, error('Expected 2 SCCs, got %d.', numel(plan)), end

% The {a,b} block has no endo deps, so it must come first.
if ~isequal(sort(plan(1).vars), sort({'a', 'b'}))
    error('Block 1 should be {a, b}, got {%s}.', strjoin(sort(plan(1).vars), ', '))
end
if ~strcmp(plan(1).kind, 'simultaneous'), error('Block 1 should be simultaneous.'), end
if ~isempty(plan(1).deps), error('Block 1 should have no already-solved endo deps.'), end

% The {y, c, h, k} block depends on {a, b}.
if ~isequal(sort(plan(2).vars), sort({'c', 'h', 'k', 'y'}))
    error('Block 2 should be {y, c, h, k}, got {%s}.', strjoin(sort(plan(2).vars), ', '))
end
if ~strcmp(plan(2).kind, 'simultaneous'), error('Block 2 should be simultaneous.'), end
if ~isequal(sort(plan(2).deps), sort({'a', 'b'}))
    error('Block 2 should depend on {a, b}, got {%s}.', strjoin(sort(plan(2).deps), ', '))
end

fprintf('t06.m: rbc3 SCC decomposition OK\n');
