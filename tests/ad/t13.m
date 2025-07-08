% Test overloaded cos function

a = autoDiff1(0, 2);
c = cos(a);
assert(abs(c.x - cos(0)) < 1e-12 && abs(c.dx + sin(0)*2) < 1e-12, 'cos failed');
