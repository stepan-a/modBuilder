% Test overloaded min function

a = autoDiff1(2, 3);
b = autoDiff1(1, 4);
c = min(a, b);
assert(c.x == 1 && c.dx == 4, 'min failed');
