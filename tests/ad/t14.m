% Test overloaded tan function

a = autoDiff1(0.1, 1);
c = tan(a);
assert(abs(c.x - tan(0.1)) < 1e-12 && abs(c.dx - 1/cos(0.1)^2) < 1e-12, 'tan failed');
