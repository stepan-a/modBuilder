% Test overloaded sin function

a = autoDiff1(pi/2, 1);
c = sin(a);
assert(abs(c.x - sin(pi/2)) < 1e-12 && abs(c.dx - cos(pi/2)) < 1e-12, 'sin failed');
