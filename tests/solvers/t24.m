% Integration test: Newton on a residual containing abs(...).
% Verifies that the autoDiff1 sub-gradient convention (abs(0).dx = 0,
% post-patch) flows correctly into the Newton solver. Three scenarios:
%
%   1. Smooth-side convergence to the positive root.
%   2. Smooth-side convergence to the negative root.
%   3. Iterate launched exactly on the kink: derivative is the sub-gradient
%      0, Newton's singular-Jacobian check fires cleanly (no NaN
%      propagation, no opaque max-iter exit), reported through flag=2.

residual = @(x) abs(x) - 0.5;     % roots at x = ±0.5; kink at x = 0

% (1) Positive side.
[x, fval, iter, flag] = solvers.newton(residual, 0.3, 1e-10, 50);
assert(flag == 0,                 'expected flag=0, got %d (positive side)', flag);
assert(abs(x  - 0.5)   < 1e-10,   'positive-side root should be 0.5, got %g', x);
assert(abs(fval)       < 1e-10,   'residual at positive root should be ~0');

% (2) Negative side.
[x, fval, iter, flag] = solvers.newton(residual, -0.3, 1e-10, 50);
assert(flag == 0,                 'expected flag=0, got %d (negative side)', flag);
assert(abs(x  - -0.5)  < 1e-10,   'negative-side root should be -0.5, got %g', x);
assert(abs(fval)       < 1e-10,   'residual at negative root should be ~0');

% (3) Start exactly at the kink: derivative is the sub-gradient 0.
% Pre-autoDiff1-patch this would have produced derivative = NaN; post-patch
% the sub-gradient is 0, and the singular-Jacobian guard catches it cleanly,
% reported through flag=2 rather than a thrown error.
[x, fval, iter, flag] = solvers.newton(residual, 0, 1e-10, 50);
assert(flag == 2, 'newton at the kink should report flag=2 (singular Jacobian), got %d', flag);
