% steady_plan: a zero-mean VAR block closes at the all-zero steady state.
%
% A stationary VAR in levels with zero-mean innovations is HOMOGENEOUS in its
% variables, so the block scale-freedom test flags it; but the scale ray exists
% only when the system matrix is singular, and det(I - A) evaluated at the
% calibration is non-zero for a stationary VAR. The linear path must then keep
% the block (its unique solution x = 0 is the legitimate steady state) instead
% of handing it to the gauge machinery, which would leave the level open.

m = modBuilder();
m.add('x1', 'x1 = a11*x1(-1) + a12*x2(-1) + e1');
m.add('x2', 'x2 = a21*x1(-1) + a22*x2(-1) + e2');
m.parameter('a11', 0.5);
m.parameter('a12', 0.2);
m.parameter('a21', 0.1);
m.parameter('a22', 0.4);
m.exogenous('e1', 0);
m.exogenous('e2', 0);

b = m.steady_plan(PropagateKnown=true);
blk = b(arrayfun(@(z) strcmp(z.kind, 'simultaneous'), b));
assert(isscalar(blk), 'expected a single simultaneous block');
assert(numel(blk.closed_form) == 2, 'the VAR block must close both variables');
vals = struct('a11', 0.5, 'a12', 0.2, 'a21', 0.1, 'a22', 0.4, 'e1', 0, 'e2', 0);
for j = 1:numel(blk.closed_form)
    vals.(blk.closed_form(j).var) = ast(blk.closed_form(j).expr).staticise().eval(vals);
end
assert(abs(vals.x1) < 1e-12 && abs(vals.x2) < 1e-12, 'zero-mean VAR steady state must be 0');

% A VAR with intercepts closes at the analytical level (I - A) \ c.
m2 = modBuilder();
m2.add('y1', 'y1 = c1 + b11*y1(-1) + b12*y2(-1) + u1');
m2.add('y2', 'y2 = c2 + b21*y1(-1) + b22*y2(-1) + u2');
m2.parameter('c1', 1);
m2.parameter('c2', 2);
m2.parameter('b11', 0.5);
m2.parameter('b12', 0.2);
m2.parameter('b21', 0.1);
m2.parameter('b22', 0.4);
m2.exogenous('u1', 0);
m2.exogenous('u2', 0);

b2 = m2.steady_plan(PropagateKnown=true);
blk2 = b2(arrayfun(@(z) strcmp(z.kind, 'simultaneous'), b2));
assert(isscalar(blk2) && numel(blk2.closed_form) == 2, 'the intercept VAR block must close');
vals2 = struct('c1', 1, 'c2', 2, 'b11', 0.5, 'b12', 0.2, 'b21', 0.1, 'b22', 0.4, 'u1', 0, 'u2', 0);
for j = 1:numel(blk2.closed_form)
    vals2.(blk2.closed_form(j).var) = ast(blk2.closed_form(j).expr).staticise().eval(vals2);
end
truth = ([1, 0; 0, 1] - [0.5, 0.2; 0.1, 0.4]) \ [1; 2];
assert(abs(vals2.y1 - truth(1)) < 1e-12 && abs(vals2.y2 - truth(2)) < 1e-12, 'intercept VAR steady state must match (I-A)\\c');

fprintf('steady-plan/t33: zero-mean VAR closes at 0, intercept VAR at (I-A)\\c\n');
