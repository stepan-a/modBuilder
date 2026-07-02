% steady_plan(Match=true, Anchors=...): a user-declared normalisation anchor is
% pulled out of the coupling like an exogenous process, breaking a simultaneous
% block. Fixing the anchor leaves one equation unmatched -- the consistency
% condition -- reported as the equation of the anchor block.
%
% x and y form a homogeneous 2-cycle (x = a*y, y = b*x): under the declaration
% pairing they are a size-2 simultaneous block. Declaring x as an anchor fixes
% its (scale) level; y is then determined by y = b*x, and x's equation becomes
% the consistency condition a*b = 1. z depends on both and resolves downstream.

m = modBuilder();
m.add('x', 'x = a*y');
m.add('y', 'y = b*x');
m.add('z', 'z = x + y');
m.parameter('a', 2);
m.parameter('b', 0.5);

% Without anchors: x and y are a simultaneous 2-block.
b0 = m.steady_plan(Match=true);
big0 = max(arrayfun(@(x) numel(x.vars), b0));
assert(big0 == 2, 'x,y should form a size-2 simultaneous block, got %d', big0);

% With x anchored: the cycle breaks, everything becomes a singleton.
bA = m.steady_plan(Match=true, Anchors={'x'});
kindof = dictionary();
for k = 1:numel(bA)
    kindof(bA(k).vars{1}) = bA(k).kind;
end
assert(strcmp(kindof('x'), 'anchor'), 'x must be an anchor, got %s', kindof('x'));
assert(max(arrayfun(@(x) numel(x.vars), bA)) == 1, 'anchoring x must triangularise to singletons');
assert(~strcmp(kindof('y'), 'anchor'), 'y is determined by x, not an anchor');

% The anchor carries no closed form (its value is user-supplied).
xb = bA(arrayfun(@(x) strcmp(x.vars{1}, 'x'), bA));
assert(isempty(xb.closed_form), 'anchor x must have no closed form');

% y is determined once x is known: y = b*x is a genuine closed form.
yb = bA(arrayfun(@(x) strcmp(x.vars{1}, 'y'), bA));
assert(~isempty(yb.closed_form) && ismember('x', yb.deps), 'y must resolve from the anchored x');

% Error handling.
threw = false;
try, m.steady_plan(Anchors={'x'}); catch e, threw = strcmp(e.identifier, 'modBuilder:steady_plan:anchorsNeedMatch'); end
assert(threw, 'Anchors without Match must error');

threw = false;
try, m.steady_plan(Match=true, Anchors={'a'}); catch e, threw = strcmp(e.identifier, 'modBuilder:steady_plan:badAnchor'); end
assert(threw, 'a non-endogenous anchor must error');

fprintf('steady-plan/t26: normalisation anchor breaks the homogeneous cycle (%d -> 1)\n', big0);
