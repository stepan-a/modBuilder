% Test overloaded max function

a = autoDiff1(2, 3);
b = autoDiff1(1, 4);
c = max(a, b);
assert(c.x == 2 && c.dx == 3, 'max failed');
