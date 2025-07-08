% Test overloaded log function

a = autoDiff1(2, 3);
c = log(a);
assert(abs(c.x - log(2)) < 1e-12 && abs(c.dx - 3/2) < 1e-12, 'log failed');
