% Test overloaded sinh function

a = autoDiff1(0.5, 2);
c = sinh(a);
assert(abs(c.x - sinh(0.5)) < 1e-12 && abs(c.dx - cosh(0.5)*2) < 1e-12, 'sinh failed');
