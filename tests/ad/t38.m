% Test overloaded cbrt function.
% Pre-patch cbrt(autoDiff1(0,*)) errored out and cbrt(autoDiff1(-8,*))
% errored out. Post-patch:
%  - cbrt(autoDiff1(0,*)) returns (0, +Inf) (let IEEE express the slope)
%  - cbrt(autoDiff1(-8,*)) returns the real value -2 (nthroot handles
%    negatives natively)

% Positive interior point.
a = cbrt(autoDiff1(8, 1));
assert(abs(a.x  - 2)            < 1e-12, 'cbrt(8).x should be 2');
assert(abs(a.dx - 1/(3*4))      < 1e-12, 'cbrt(8).dx should be 1/(3*4) = 1/12');

% Negative interior point: cbrt is real-valued on all reals.
b = cbrt(autoDiff1(-8, 1));
assert(abs(b.x  - -2)           < 1e-12, 'cbrt(-8).x should be -2');
assert(abs(b.dx - 1/(3*4))      < 1e-12, 'cbrt(-8).dx should be 1/(3*4) = 1/12');

% At zero: value 0, derivative +Inf with positive seed.
c = cbrt(autoDiff1(0, 1));
assert(c.x  == 0,   'cbrt(0).x should be 0');
assert(c.dx == Inf, 'cbrt(0).dx should be +Inf with positive seed');

% At zero with negative seed: derivative -Inf.
c2 = cbrt(autoDiff1(0, -1));
assert(c2.dx == -Inf, 'cbrt(0).dx should be -Inf with negative seed');
