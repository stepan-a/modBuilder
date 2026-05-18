% Test overloaded sqrt function.
% At o.x = 0 the derivative must be +Inf (IEEE division by zero), letting
% the Newton solvers detect a non-finite derivative on the next iteration
% rather than silently producing a NaN downstream.
% At o.x < 0 the function raises autoDiff1:sqrt:domain.

% Smooth interior point: value and derivative correct.
a = autoDiff1(4, 1);
c = sqrt(a);
assert(abs(c.x  - 2)     < 1e-12, 'sqrt(4).x should be 2');
assert(abs(c.dx - 0.25)  < 1e-12, 'sqrt(4).dx should be 1/(2*2) = 0.25');

% At zero: value 0, derivative +Inf (positive seed).
b = sqrt(autoDiff1(0, 1));
assert(b.x  == 0,   'sqrt(0).x should be 0');
assert(b.dx == Inf, 'sqrt(0).dx should be +Inf with positive seed');

% At zero with negative seed: derivative -Inf.
b2 = sqrt(autoDiff1(0, -1));
assert(b2.dx == -Inf, 'sqrt(0).dx should be -Inf with negative seed');

% Negative argument: structured domain error.
threw = false;
try
    sqrt(autoDiff1(-1, 1));
catch e
    threw = true;
    assert(strcmp(e.identifier, 'autoDiff1:sqrt:domain'), ...
           'Expected autoDiff1:sqrt:domain, got %s', e.identifier);
end
assert(threw, 'sqrt(-1) should error');
