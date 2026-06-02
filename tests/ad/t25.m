% Test overloaded min function

a = autoDiff1(2, 3);
b = autoDiff1(1, 4);
c = min(a, b);
assert(c.x == 1 && c.dx == 4, 'min failed');

% Test with mixed types (autoDiff1 and numeric)
c = min(a, 5);
assert(c.x == 2 && c.dx == 3, 'min(autoDiff1, numeric) failed');

c = min(5, a);
assert(c.x == 2 && c.dx == 3, 'min(numeric, autoDiff1) failed');

c = min(a, 1);
assert(c.x == 1 && c.dx == 0, 'min(autoDiff1, smaller numeric) failed');

% At the tie (equal values) min returns the averaged sub-gradient, not an error.
d = autoDiff1(2, 7);
c = min(a, d);
assert(c.x == 2 && c.dx == (3 + 7)/2, 'min at the tie should average the sub-gradients');
