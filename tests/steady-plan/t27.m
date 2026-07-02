% steady_plan(Match=true) with a calibration swap: fixing an endogenous and
% freeing a parameter that appears in ANOTHER equation (a non-local swap) is
% resolved by re-running the matching on the swapped unknown set. The freed
% parameter is matched to the equation it settles; the fixed endogenous becomes
% a known constant, breaking a simultaneous block.
%
% h = a*w (keyed h) and w = chi*h (keyed w) form a 2-cycle. Pinning h and freeing
% chi -- which appears in w's equation, not h's -- triangularises it: w = a*h,
% then chi = w/h.

m = modBuilder();
m.add('h', 'h = a*w');
m.add('w', 'w = chi*h');
m.parameter('a', 2);
m.parameter('chi', 3);

% Before the swap: {h, w} is a size-2 simultaneous block.
b0 = m.steady_plan(Match=true);
assert(max(arrayfun(@(x) numel(x.vars), b0)) == 2, 'h,w should be a size-2 block');

% Non-local swap: chi appears in w's equation, not in h's -> allowed by calibrate
% (global admissibility) and resolved by Match.
m.calibrate('h', 0.3, 'chi');
b1 = m.steady_plan(Match=true);
assert(max(arrayfun(@(x) numel(x.vars), b1)) == 1, 'the swap must triangularise to singletons');

% chi is now a solved unknown; h is a known constant (not a block variable).
allvars = [b1.vars];
assert(ismember('chi', allvars), 'freed parameter chi must appear as a solved variable');
assert(~ismember('h', allvars), 'calibrated h must be a known constant, not a block variable');

% The same non-local swap is rejected by the declaration-pairing path.
threw = false;
try, m.steady_plan(); catch e, threw = strcmp(e.identifier, 'modBuilder:steady_plan'); end
assert(threw, 'a non-local swap must be rejected without Match');

fprintf('steady-plan/t27: non-local calibration swap triangularises under Match\n');
