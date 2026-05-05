% Tier 1 — joint AR(1): two equations mutually referencing each other plus self-references.
% Expected: a single SCC of size 2.

m = modBuilder();
m.add('a', 'a = rho*a(-1) + tau*b(-1) + e');
m.add('b', 'b = tau*a(-1) + rho*b(-1) + u');
m.parameter('rho', 0.95);
m.parameter('tau', 0.025);
m.exogenous('e', 0);
m.exogenous('u', 0);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 block (SCC of size 2), got %d.', numel(plan)), end
if ~strcmp(plan(1).kind, 'simultaneous'), error('Expected simultaneous block.'), end
if ~isequal(sort(plan(1).vars), sort({'a', 'b'}))
    error('Expected vars = {a, b}, got {%s}.', strjoin(plan(1).vars, ', '))
end
if ~isempty(plan(1).deps), error('No already-solved endo deps for the joint AR.'), end
if ~isequal(sort(plan(1).extdeps), sort({'rho', 'tau', 'e', 'u'}))
    error('Expected external constants {e, rho, tau, u}, got {%s}.', strjoin(sort(plan(1).extdeps), ', '))
end

fprintf('t05.m: joint AR SCC OK\n');
