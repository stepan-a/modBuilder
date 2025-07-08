% Test overloaded acos function

a = autoDiff1(0.5, 1);
c = acos(a);
assert(abs(c.x - acos(0.5)) < 1e-12 && abs(c.dx + 1/sqrt(1 - 0.5^2)) < 1e-12, 'acos failed');
