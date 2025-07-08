% Test overloaded cosh function

a = autoDiff1(0.5, 2);
c = cosh(a);
assert(abs(c.x - cosh(0.5)) < 1e-12 && abs(c.dx - sinh(0.5)*2) < 1e-12, 'cosh failed');
