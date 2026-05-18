% Tests for autoDiff1 hyperbolic domain errors

% Test 1: acosh with argument <= 1
thrown = false;
try
    acosh(autoDiff1(0.5, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: acosh domain error.');

% acosh(1) is now valid (value = 0, derivative = Inf via IEEE
% sqrt(0) → 0 → division by zero). The function value is well-defined.
r = acosh(autoDiff1(1.0, 1));
assert(r.x == 0,    'acosh(1) value should be 0.');
assert(isinf(r.dx), 'acosh(1) derivative should be Inf.');

% Test 2: atanh with |argument| >= 1. Unlike asin/acos/acosh, the
% atanh function itself diverges to ±Inf at |x| = 1 (not just its
% derivative), so the boundary stays excluded from the domain.
thrown = false;
try
    atanh(autoDiff1(1.5, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: atanh domain error (>1).');

thrown = false;
try
    atanh(autoDiff1(-1.0, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: atanh at boundary (function diverges).');
