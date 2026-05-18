% Test overloaded abs function at the kink.
% Pre-patch abs(autoDiff1(0,*)) returned (0, NaN). Post-patch returns the
% sub-gradient choice (0, 0) — consistent with Dynare's sign(0) = 0
% convention. Non-zero arguments must keep the analytic derivative.

% At the kink: sub-gradient = 0.
a = autoDiff1(0, 5);
c = abs(a);
assert(c.x == 0,                       'abs(0).x should be 0');
assert(c.dx == 0,                      'abs(0).dx should be 0 (sub-gradient), not NaN');
assert(isfinite(c.dx),                 'abs(0).dx must be finite');

% Positive side: derivative = +o.dx.
b = autoDiff1(2.5, 7);
d = abs(b);
assert(abs(d.x - 2.5)  < 1e-12,        'abs(2.5).x should be 2.5');
assert(abs(d.dx - 7)   < 1e-12,        'abs(2.5).dx should be 7 (sign = +1)');

% Negative side: derivative = -o.dx.
e = autoDiff1(-3, 4);
f = abs(e);
assert(abs(f.x - 3)    < 1e-12,        'abs(-3).x should be 3');
assert(abs(f.dx - -4)  < 1e-12,        'abs(-3).dx should be -4 (sign = -1)');
