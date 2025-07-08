% Test overloaded mtimes (*) method

a = autoDiff1(3, 1);
b = autoDiff1(4, 2);
c = a * b;
assert(c.x == 12 && c.dx == 3*2 + 1*4, '* operator failed');
