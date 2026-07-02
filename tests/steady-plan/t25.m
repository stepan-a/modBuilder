% steady_plan(Match=true): economically exogenous variables (AR/ARMA/VAR driving
% processes) are identified structurally and pulled out of the coupling.
%
% - z is an AR(1): references only its own lag and an innovation -> exogenous.
% - {v1, v2} form a VAR(1): each references only block members and innovations
%   -> both exogenous (a sink block of the dependency graph driven by shocks).
% - w is driven by z (another endogenous) plus its own lag: it is DETERMINED by
%   z, not a free exogenous -> not an anchor.
% - y is a plain endogenous.
%
% The test checks the structural criterion, which does not rely on any
% STEADY_STATE self-reference syntax.

m = modBuilder();
m.add('z',  'z = rho*z(-1) + e_z');
m.add('v1', 'v1 = 0.5*v1(-1) + 0.1*v2(-1) + e1');
m.add('v2', 'v2 = 0.2*v1(-1) + 0.6*v2(-1) + e2');
m.add('w',  'w = 0.5*w(-1) + z + e_w');
m.add('y',  'y = z + v1 + w');
m.parameter('rho', 0.8);
m.exogenous('e_z', 0);
m.exogenous('e1', 0);
m.exogenous('e2', 0);
m.exogenous('e_w', 0);

b = m.steady_plan(Match=true);
kindof = dictionary();
for k = 1:numel(b)
    kindof(b(k).vars{1}) = b(k).kind;
end

% AR(1) and VAR(1) members are exogenous anchors.
assert(strcmp(kindof('z'),  'anchor'), 'z (AR(1)) should be an anchor, got %s',  kindof('z'));
assert(strcmp(kindof('v1'), 'anchor'), 'v1 (VAR) should be an anchor, got %s', kindof('v1'));
assert(strcmp(kindof('v2'), 'anchor'), 'v2 (VAR) should be an anchor, got %s', kindof('v2'));

% w is determined by z (not a free exogenous), y is endogenous.
assert(~strcmp(kindof('w'), 'anchor'), 'w is driven by z, not a free anchor');
assert(~strcmp(kindof('y'), 'anchor'), 'y is endogenous, not an anchor');

% Without Match, the anchor kind never appears.
b0 = m.steady_plan();
assert(~any(strcmp({b0.kind}, 'anchor')), 'anchor kind must only appear with Match=true');

fprintf('steady-plan/t25: AR(1) z and VAR {v1,v2} identified as exogenous anchors; w excluded\n');
