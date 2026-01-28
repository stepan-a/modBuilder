% Tests for autoDiff1 mpower branches and errors

% Test 1: numeric^autoDiff1 with positive base
x = autoDiff1(3, 1);
q = 2^x;
assert(abs(q.x - 8) < 1e-10, 'numeric^autoDiff1: value');
assert(abs(q.dx - 8*log(2)) < 1e-10, 'numeric^autoDiff1: derivative');

% Test 2: numeric^autoDiff1 with non-positive base
thrown = false;
try
    q = (-2)^autoDiff1(3, 1);
catch
    thrown = true;
end
assert(thrown, 'Expected error: base must be positive.');

% Test 3: autoDiff1^autoDiff1 with positive base
a = autoDiff1(2, 1);
b = autoDiff1(3, 0);
q = a^b;
assert(abs(q.x - 8) < 1e-10, 'autoDiff1^autoDiff1: value');

% Test 4: autoDiff1^autoDiff1 with non-positive base
thrown = false;
try
    q = autoDiff1(-2, 1)^autoDiff1(3, 0);
catch
    thrown = true;
end
assert(thrown, 'Expected error: base must be positive (dual^dual).');
