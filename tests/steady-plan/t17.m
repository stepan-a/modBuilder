% steady_plan: iterated elimination closes a bilinear block that joint-linearity
% cannot. After substituting a = d*y into a*y = b-c, the residual becomes monomial
% in y (degree 2) and isolation succeeds.

addpath ../utils

m = modBuilder();
m.add('y', 'a*y = b - c');     % bilinear in (y, a) — Phase 4 rejects
m.add('a', 'a = d*y');
m.parameter('b', 1);
m.parameter('c', 0);
m.parameter('d', 4);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 SCC.'), end
if ~strcmp(plan(1).kind, 'simultaneous'), error('Expected simultaneous block, got %s.', plan(1).kind), end
if numel(plan(1).closed_form) ~= 2
    error('Expected 2 closed-form entries (full closure), got %d.', numel(plan(1).closed_form))
end

% Numerical verification: y = sqrt((b-c)/d) = sqrt(0.25) = 0.5; a = d*y = 2.
values = struct('b', 1, 'c', 0, 'd', 4);
for j = 1:numel(plan(1).closed_form)
    val = ast(plan(1).closed_form(j).expr).eval(values);
    values.(plan(1).closed_form(j).var) = val;
end

if abs(values.y - 0.5) > 1e-10
    error('y closed form: got %g, expected 0.5.', values.y)
end
if abs(values.a - 2) > 1e-10
    error('a closed form: got %g, expected 2.', values.a)
end

fprintf('t17.m: iterated elimination closes bilinear 2-eq block OK\n');
