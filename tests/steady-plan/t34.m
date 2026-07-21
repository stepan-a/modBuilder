% steady_plan: the ADDITIVE log form of an exogenous process closes analytically.
%
% log(Z) = rho*log(Z(-1)) + ez leaves the static residual log(Z) - rho*log(Z) - ez,
% where the two log(Z) occurrences carry symbolic coefficients (1 and -rho) that no
% collect pass merges. The invertible-call recogniser accepts several occurrences of
% the same call subtree (summing their coefficients), so u = log(Z) is pinned and
% Z = exp(ez/(1-rho)) -- the level Z = 1 at ez = 0, a legitimate root (not a trivial
% ray). Same for the centred variant log(W/wbar) = rw*log(W(-1)/wbar) + ew, whose
% level is the explicit parameter: W = wbar.

m = modBuilder();
m.add('Z', 'log(Z) - rho*log(Z(-1)) - ez');
m.add('W', 'log(W/wbar) - rw*log(W(-1)/wbar) - ew');
m.add('Y', 'Y - Z*K^alpha');
m.add('K', 'K - s*Y*W');
m.parameter('rho', 0.9);
m.parameter('rw', 0.8);
m.parameter('wbar', 1.5);
m.parameter('alpha', 0.3);
m.parameter('s', 0.2);
m.exogenous('ez', 0);
m.exogenous('ew', 0);

b = m.steady_plan(Match=true);

vals = struct('rho', 0.9, 'rw', 0.8, 'wbar', 1.5, 'alpha', 0.3, 's', 0.2, 'ez', 0, 'ew', 0);
resolved = {};
for k = 1:numel(b)
    cf = b(k).closed_form;
    for j = 1:numel(cf)
        vals.(cf(j).var) = ast(cf(j).expr).eval(vals);
        resolved{end+1} = cf(j).var; %#ok<AGROW>
    end
end

assert(all(ismember({'Z', 'W', 'Y', 'K'}, resolved)), 'steady_plan must close the whole model in closed form');
assert(abs(vals.Z - 1) < 1e-12, 'Z* must be 1 (log AR process at ez = 0)');
assert(abs(vals.W - vals.wbar) < 1e-12, 'W* must be wbar (centred log AR process at ew = 0)');
assert(abs(vals.Y - vals.Z*vals.K^vals.alpha) < 1e-9, 'Y equation must hold at the recovered point');
assert(abs(vals.K - vals.s*vals.Y*vals.W) < 1e-9, 'K equation must hold at the recovered point');

fprintf('steady-plan/t34: additive log AR processes close via the multi-occurrence invertible call\n');
