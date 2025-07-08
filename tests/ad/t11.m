% Test overloaded cbrt function

a = autoDiff1(8, 3);
c = cbrt(a);
assert(abs(c.x - 2) < 1e-12 && abs(c.dx - 3/(3*2^2)) < 1e-12, 'cbrt failed');
