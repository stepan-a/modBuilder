% steady_plan: GAUGE BACKOUT. A normalisation anchor frees its equation for
% re-matching; when the matcher settles that freed (degree-0) equation inside a
% block, the block becomes HOMOGENEOUS in its variables -- its equations pin the
% ratios but not the level, and the level-pinning equation ends up among the
% consistency conditions absorbed by the anchors. The plan must then parametrise
% the block in a gauge (ratios in closed form) and back the level out of the
% consistency equation, instead of letting elimination "close" the block on the
% trivial all-zero ray.
%
% Mini price-recursion model: anchoring p frees the optimal-price equation
% z1/z2 = p (degree 0), which the matcher prefers over the level equation
% k^aa = y (the LHS tie-breaker favours z1 for the freed equation and y for a
% recursion). The block {z1, z2, y} is then scale-free and k^aa = y is the
% consistency condition that pins the level.

m = modBuilder();
m.add('p', 'z1/z2 = p');
m.add('z1', 'lam*y = z1 - del*z1');
m.add('z2', 'lam*y = z2 - dee*z2');
m.add('y', 'k^aa = y');
m.parameter('lam', 2);
m.parameter('del', 0.5);
m.parameter('dee', 0.6);
m.parameter('k', 3);
m.parameter('aa', 0.3);

b = m.steady_plan(Match=true, Anchors={'p'});

% The simultaneous block must be fully closed, with the backout recorded.
blk = b(arrayfun(@(z) strcmp(z.kind, 'simultaneous'), b));
assert(isscalar(blk), 'expected a single simultaneous block');
assert(numel(blk.closed_form) == numel(blk.vars), 'gauge backout must close the whole block');
assert(~isempty(blk.backout), 'backout metadata must be recorded');
assert(strcmp(blk.backout.eq, 'y'), 'the level must come from the consistency equation "y"');
assert(ismember(blk.backout.gauge, blk.vars), 'the gauge must be a block variable');

% Numerical check against the hand solution: the anchor value p = (1-dee)/(1-del)
% is consistent with the redundant optimal-price equation; y = k^aa,
% z1 = lam*y/(1-del), z2 = lam*y/(1-dee).
vals = struct('lam',2,'del',0.5,'dee',0.6,'k',3,'aa',0.3,'p',(1-0.6)/(1-0.5));
for jj = 1:numel(blk.closed_form)
    vals.(blk.closed_form(jj).var) = ast(blk.closed_form(jj).expr).eval(vals);
end
assert(abs(vals.y - 3^0.3) < 1e-9, 'y must equal k^aa');
assert(abs(vals.z1 - 2*3^0.3/0.5) < 1e-9, 'z1 must equal lam*y/(1-del)');
assert(abs(vals.z2 - 2*3^0.3/0.4) < 1e-9, 'z2 must equal lam*y/(1-dee)');
assert(abs(vals.z1/vals.z2 - vals.p) < 1e-9, 'the anchored equation must hold as a consistency check');

fprintf('steady-plan/t30: gauge backout closes the scale-free block {%s} via eq "y" (gauge %s)\n', strjoin(blk.vars, ', '), blk.backout.gauge);
