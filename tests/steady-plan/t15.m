% steady_plan: bilinear simultaneous SCC. The joint-linearity check rejects the
% block, but iterated elimination still resolves one of the two variables: the
% recognisers fire on each equation individually, so the algorithm picks one
% (var, eq) pair, substitutes, and finds the resulting equation in the remaining
% variable to be quadratic — beyond the recogniser allowlist. Result: 1 of 2
% vars resolved, 1 left as residual.

addpath ../utils

m = modBuilder();
m.add('a', 'a = rho*a(-1) + b*c');
m.add('b', 'b = a*b(-1) + u');
m.parameter('rho', 0.5);
m.exogenous('c', 1);
m.exogenous('u', 1);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 SCC.'), end
if ~strcmp(plan(1).kind, 'simultaneous'), error('Expected simultaneous block.'), end

resolved = {plan(1).closed_form.var};
residual = setdiff(plan(1).vars, resolved);
if numel(resolved) ~= 1
    error('Expected 1 resolved var (partial closure), got %d.', numel(resolved))
end
if numel(residual) ~= 1
    error('Expected 1 residual var, got %d.', numel(residual))
end

fprintf('t15.m: partial closure on bilinear block (1 resolved + 1 residual) OK\n');
