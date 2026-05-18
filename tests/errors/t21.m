% Tests for autoDiff1 trigonometric domain errors

% Test 1: tan at asymptote
thrown = false;
try
    tan(autoDiff1(pi/2, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: tan at asymptote.');

% Test 2: asin out of domain
thrown = false;
try
    asin(autoDiff1(1.5, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: asin domain error (>1).');

thrown = false;
try
    asin(autoDiff1(-1.5, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: asin domain error (<-1).');

% asin(±1) is now valid (value = ±pi/2, derivative = Inf via IEEE
% sqrt(0) → 0 → division by zero). Same shape as the sqrt(0) /
% cbrt(0) relaxations: the function value is well-defined, the
% singular derivative is surfaced by IEEE Inf.
r = asin(autoDiff1(1.0, 1));
assert(abs(r.x - pi/2) < 1e-12, 'asin(1) value should be pi/2.');
assert(isinf(r.dx),             'asin(1) derivative should be Inf.');

r = asin(autoDiff1(-1.0, 1));
assert(abs(r.x - -pi/2) < 1e-12, 'asin(-1) value should be -pi/2.');
assert(isinf(r.dx),              'asin(-1) derivative should be Inf.');

% Test 3: acos out of domain
thrown = false;
try
    acos(autoDiff1(2.0, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: acos domain error.');
