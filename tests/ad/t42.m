% Test overloaded sign function, including at the kink.
% sign is piecewise-constant: the derivative is 0 wherever defined. At x = 0 the
% distributional derivative is a Dirac delta; we return the finite sub-gradient
% (0, 0) rather than erroring, consistent with abs / min / max and Dynare's
% sign(0) = 0 convention (and with ast.diff_ast, which emits sign(u)' = 0).

% Positive side: sign = +1, derivative 0.
a = autoDiff1(2.5, 7);
c = sign(a);
assert(c.x == 1  && c.dx == 0, 'sign(positive) should be (1, 0)');

% Negative side: sign = -1, derivative 0.
b = autoDiff1(-3, 4);
c = sign(b);
assert(c.x == -1 && c.dx == 0, 'sign(negative) should be (-1, 0)');

% At the kink: finite sub-gradient (0, 0), not an error.
z = autoDiff1(0, 5);
c = sign(z);
assert(c.x == 0  && c.dx == 0, 'sign(0) should be the sub-gradient (0, 0)');
assert(isfinite(c.dx),         'sign(0).dx must be finite');
