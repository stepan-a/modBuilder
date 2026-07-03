% steady_plan: MULTI-GAUGE backout. Two price-recursion groups, each scale-free,
% coupled only through degree-0 (ratio) terms: one strongly connected block with
% TWO independent scale freedoms. Anchoring pa and pb frees both degree-0
% optimal-price equations into the block, and the two level equations (ka^aa = ya,
% kb^ab = yb) end up among the consistency conditions. The backout must close both
% gauges: the levels come from the consistency equations, the remaining block
% equations then resolve one variable each -- some parametrically in a gauge
% closed later, which exercises the topological ordering of the gauge assignments.

m = modBuilder();
m.add('pa', 'za1/za2 = pa');
m.add('za1', 'la*ya = za1 - da*za1');
m.add('za2', 'la*ya*(zb1/zb2) = za2 - ea*za2');
m.add('ya', 'ka^aa = ya');
m.add('pb', 'zb1/zb2 = pb');
m.add('zb1', 'lb*yb = zb1 - db*zb1');
m.add('zb2', 'lb*yb*(za1/za2) = zb2 - eb*zb2');
m.add('yb', 'kb^ab = yb');
m.parameter('la', 2);
m.parameter('lb', 3);
m.parameter('da', 0.5);
m.parameter('ea', 0.6);
m.parameter('db', 0.5);
m.parameter('eb', 0.6);
m.parameter('ka', 3);
m.parameter('aa', 0.3);
m.parameter('kb', 2);
m.parameter('ab', 0.4);
% consistent anchor values: pa*pb = (1-ea)/(1-da) = (1-eb)/(1-db) = 0.8
m.steady('pa', '1');
m.steady('pb', '0.8');

b = m.steady_plan(Match=true, Anchors={'pa','pb'}, PropagateKnown=true);

blk = b(arrayfun(@(z) strcmp(z.kind, 'simultaneous'), b));
assert(isscalar(blk), 'expected a single simultaneous block (the coupled core)');
assert(numel(blk.vars) == 6, 'the coupled core must hold the six za/zb/y variables');
assert(numel(blk.closed_form) == numel(blk.vars), 'multi-gauge backout must close the whole block');
assert(~isempty(blk.backout) && iscell(blk.backout.gauge) && numel(blk.backout.gauge) >= 2, 'a multi-gauge backout must be recorded');

% Numerical check against the hand solution.
vals = struct('la',2,'lb',3,'da',0.5,'ea',0.6,'db',0.5,'eb',0.6,'ka',3,'aa',0.3,'kb',2,'ab',0.4,'pa',1,'pb',0.8);
for jj = 1:numel(blk.closed_form)
    vals.(blk.closed_form(jj).var) = ast(blk.closed_form(jj).expr).eval(vals);
end
ya = 3^0.3; yb = 2^0.4;
assert(abs(vals.ya - ya) < 1e-9, 'ya must equal ka^aa');
assert(abs(vals.yb - yb) < 1e-9, 'yb must equal kb^ab');
assert(abs(vals.za1 - 2*ya/0.5) < 1e-9, 'za1 must equal la*ya/(1-da)');
assert(abs(vals.za2 - 2*ya*0.8/0.4) < 1e-9, 'za2 must equal la*ya*pb/(1-ea)');
assert(abs(vals.zb1 - 3*yb/0.5) < 1e-9, 'zb1 must equal lb*yb/(1-db)');
assert(abs(vals.zb2 - 3*yb*1/0.4) < 1e-9, 'zb2 must equal lb*yb*pa/(1-eb)');
assert(abs(vals.za1/vals.za2 - 1) < 1e-9 && abs(vals.zb1/vals.zb2 - 0.8) < 1e-9, 'the anchored ratios must hold');

fprintf('steady-plan/t32: multi-gauge backout closes {%s} (gauges: %s)\n', strjoin(blk.vars, ', '), strjoin(blk.backout.gauge, ', '));
