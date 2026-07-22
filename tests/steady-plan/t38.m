% steady_plan: a multivariate exogenous process (VAR) stays ONE anchor block.
%
% Cutting the dependencies between process siblings used to split the VAR into
% anchor singletons whose closed forms referenced each other out of evaluation
% order (v = ev + k*u, u = eu + k*v), and hid the joint static system
% (I-K)x = c from the determinant probe: at k = 1, det(I-K) = 1-k^2 = 0 and the
% process has a unit root, silently. Kept together, the block closes through the
% Bareiss path in evaluation order and the knife-edge probe fires at k = 1.

m = modBuilder();
m.add('u', 'u - k*v(-1) - eu');
m.add('v', 'v - k*u(-1) - ev');
m.add('y', 'y - u - v - c0');
m.parameter('k', 0.5);
m.parameter('c0', 1);
m.exogenous('eu', 0.1);
m.exogenous('ev', 0.2);

lastwarn('');
b = m.steady_plan(Match=true);
[~, id] = lastwarn();
assert(~strcmp(id, 'modBuilder:steady_plan:calibrationUnitRoot'), 'k = 0.5 must stay silent');

% The VAR is one block of kind anchor, closed jointly, in evaluation order.
nb2 = find(arrayfun(@(x) numel(x.vars) == 2, b));
assert(isscalar(nb2), 'the VAR pair must form exactly one block of size 2');
assert(strcmp(b(nb2).kind, 'anchor'), 'the VAR block must keep the anchor kind');
assert(all(ismember(sort(b(nb2).vars), {'u', 'v'})), 'the VAR block must hold u and v');
assert(numel(b(nb2).closed_form) == 2, 'the VAR block must close both variables');

% The whole plan evaluates in block order -- the broken crossed forms used to
% make this loop fail on the first block.
vals = struct('k', 0.5, 'c0', 1, 'eu', 0.1, 'ev', 0.2);
for kk = 1:numel(b)
    for j = 1:numel(b(kk).closed_form)
        vals.(b(kk).closed_form(j).var) = ast(b(kk).closed_form(j).expr).eval(vals);
    end
end
assert(abs(vals.u - vals.k*vals.v - vals.eu) < 1e-12, 'u equation must hold at the recovered point');
assert(abs(vals.v - vals.k*vals.u - vals.ev) < 1e-12, 'v equation must hold at the recovered point');
assert(abs(vals.y - vals.u - vals.v - vals.c0) < 1e-12, 'y equation must hold at the recovered point');

% At k = 1 the process is a unit root: det(I-K) = 0 at the calibration and the
% knife-edge probe must fire on the block.
m2 = modBuilder();
m2.add('u', 'u - k*v(-1) - eu');
m2.add('v', 'v - k*u(-1) - ev');
m2.add('y', 'y - u - v - c0');
m2.parameter('k', 1);
m2.parameter('c0', 1);
m2.exogenous('eu', 0.1);
m2.exogenous('ev', 0.2);

lastwarn('');
m2.steady_plan(Match=true);
[msg, id] = lastwarn();
assert(strcmp(id, 'modBuilder:steady_plan:calibrationUnitRoot'), 'k = 1 must raise the calibrationUnitRoot warning on the VAR block');
assert(contains(msg, 'u') && contains(msg, 'v'), 'the warning must name the process variables');

fprintf('steady-plan/t38: VAR processes close as one anchor block, unit-root calibrations are flagged\n');
