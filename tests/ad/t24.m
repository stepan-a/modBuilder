% Test overloaded max function

a = autoDiff1(2, 3);
b = autoDiff1(1, 4);
c = max(a, b);
assert(c.x == 2 && c.dx == 3, 'max failed');

% Test with mixed types (autoDiff1 and numeric)
c = max(a, 1);
assert(c.x == 2 && c.dx == 3, 'max(autoDiff1, numeric) failed');

c = max(1, a);
assert(c.x == 2 && c.dx == 3, 'max(numeric, autoDiff1) failed');

c = max(a, 5);
assert(c.x == 5 && c.dx == 0, 'max(autoDiff1, larger numeric) failed');

% At the tie (equal values) max returns the averaged sub-gradient, not an error.
d = autoDiff1(2, 7);
c = max(a, d);
assert(c.x == 2 && c.dx == (3 + 7)/2, 'max at the tie should average the sub-gradients');
