% Test overloaded sqrt function

a = autoDiff1(4, 2);
c = sqrt(a);
assert(abs(c.x - 2) < 1e-12 && abs(c.dx - 2/(2*2)) < 1e-12, 'sqrt failed');
