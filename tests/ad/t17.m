% Test overloaded atan function

a = autoDiff1(1, 2);
c = atan(a);
assert(abs(c.x - atan(1)) < 1e-12 && abs(c.dx - 2/(1 + 1^2)) < 1e-12, 'atan failed');
