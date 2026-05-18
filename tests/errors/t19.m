% Tests for autoDiff1 domain errors: log, log10, sqrt, cbrt

% Test 1: log of non-positive
thrown = false;
try
    log(autoDiff1(0, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: log domain error.');

thrown = false;
try
    log(autoDiff1(-1, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: log of negative.');

% Test 2: log10 of non-positive
thrown = false;
try
    log10(autoDiff1(-1, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: log10 domain error.');

% Test 3: sqrt of non-positive
thrown = false;
try
    sqrt(autoDiff1(-1, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: sqrt domain error.');

% sqrt(0) is now valid (value=0, derivative=Inf)
r = sqrt(autoDiff1(0, 1));
assert(r.x == 0, 'sqrt(0) value should be 0.');
assert(isinf(r.dx), 'sqrt(0) derivative should be Inf.');

% Test 4: cbrt(0) is now valid (value=0, derivative=Inf). Same shape as
% the sqrt(0) relaxation above — the function value is well-defined and
% the singular derivative is surfaced via IEEE Inf, caught by the Newton
% solvers as :nonFinite on the next iteration.
r = cbrt(autoDiff1(0, 1));
assert(r.x == 0,    'cbrt(0) value should be 0.');
assert(isinf(r.dx), 'cbrt(0) derivative should be Inf.');

% cbrt is also valid for negative arguments (real-valued cube root).
r = cbrt(autoDiff1(-8, 1));
assert(abs(r.x - -2) < 1e-12, 'cbrt(-8) value should be -2.');
assert(isfinite(r.dx),        'cbrt(-8) derivative should be finite.');
