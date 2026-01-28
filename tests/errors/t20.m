% Tests for autoDiff1 sign function

% Test 1: sign of positive
x = autoDiff1(5, 1);
q = sign(x);
assert(q.x == 1, 'sign(positive) should be 1.');
assert(q.dx == 0, 'sign derivative should be 0.');

% Test 2: sign of negative
x = autoDiff1(-5, 1);
q = sign(x);
assert(q.x == -1, 'sign(negative) should be -1.');
assert(q.dx == 0, 'sign derivative should be 0.');

% Test 3: sign of zero (domain error)
thrown = false;
try
    sign(autoDiff1(0, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: sign at zero.');
