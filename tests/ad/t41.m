% Test overloaded asin / acos at the domain boundary.
% Pre-patch the boundary |x| = 1 was rejected as out-of-domain even though
% asin(±1) = ±pi/2 and acos(±1) ∈ {0, pi} are perfectly well-defined.
% Post-patch the value is returned and the (infinite) derivative is
% produced via IEEE division by zero, to be caught by Newton on the next
% iteration.

% Interior point: asin(0.5) = pi/6, derivative = 1/sqrt(1 - 0.25) = 1/sqrt(0.75).
a = asin(autoDiff1(0.5, 1));
assert(abs(a.x  - pi/6)            < 1e-12, 'asin(0.5).x should be pi/6');
assert(abs(a.dx - 1/sqrt(0.75))    < 1e-12, 'asin(0.5).dx should be 1/sqrt(0.75)');

% Boundary x = 1: value pi/2, derivative +Inf with positive seed.
b = asin(autoDiff1(1, 1));
assert(abs(b.x  - pi/2) < 1e-12, 'asin(1).x should be pi/2');
assert(b.dx == Inf,              'asin(1).dx should be +Inf with positive seed');

% Boundary x = -1: value -pi/2, derivative +Inf (denominator sqrt(0) = 0).
b2 = asin(autoDiff1(-1, 1));
assert(abs(b2.x - -pi/2) < 1e-12, 'asin(-1).x should be -pi/2');
assert(b2.dx == Inf,              'asin(-1).dx should be +Inf with positive seed');

% acos at boundary: value 0 at x=1, derivative -Inf with positive seed.
c = acos(autoDiff1(1, 1));
assert(abs(c.x) < 1e-12, 'acos(1).x should be 0');
assert(c.dx == -Inf,     'acos(1).dx should be -Inf with positive seed');

% Out-of-domain: structured error (asin).
threw = false;
try
    asin(autoDiff1(1.5, 1));
catch e
    threw = true;
    assert(strcmp(e.identifier, 'autoDiff1:asin:domain'), ...
           'Expected autoDiff1:asin:domain, got %s', e.identifier);
end
assert(threw, 'asin(1.5) should error');

% Out-of-domain: structured error (acos).
threw = false;
try
    acos(autoDiff1(-1.5, 1));
catch e
    threw = true;
    assert(strcmp(e.identifier, 'autoDiff1:acos:domain'), ...
           'Expected autoDiff1:acos:domain, got %s', e.identifier);
end
assert(threw, 'acos(-1.5) should error');
