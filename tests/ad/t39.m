% Test overloaded ^ (mpower) at the constant-exponent corner.
% Pre-patch autoDiff1(0, dx)^0 evaluated via p*o.dx*o.x^(p-1) =
% 0 * dx * 0^(-1) = 0 * Inf = NaN.
% Post-patch the p == 0 literal case is short-circuited to (1, 0).

% x^0 with x = 0: derivative is identically zero.
a = autoDiff1(0, 1)^0;
assert(a.x  == 1, 'x^0 value should be 1');
assert(a.dx == 0, 'd(x^0)/dx should be 0 (not NaN)');

% x^0 with x ≠ 0: same identity.
b = autoDiff1(5, 3)^0;
assert(b.x  == 1, '5^0 should be 1');
assert(b.dx == 0, 'd(5^0)/dx should be 0');

% Non-trivial exponent: classical chain rule kept intact.
c = autoDiff1(3, 1)^2;
assert(abs(c.x  - 9) < 1e-12, '3^2 should be 9');
assert(abs(c.dx - 6) < 1e-12, 'd(x^2)/dx at x=3 should be 2*x = 6');

% Non-positive base with differentiable exponent: structured error.
threw = false;
try
    (-1)^autoDiff1(0.5, 1);
catch e
    threw = true;
    assert(strcmp(e.identifier, 'autoDiff1:mpower:nonPositiveBase'), ...
           'Expected autoDiff1:mpower:nonPositiveBase, got %s', e.identifier);
end
assert(threw, '(-1)^autoDiff1(...) should error');
