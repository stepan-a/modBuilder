% Test overloaded acosh function

a = autoDiff1(2, 1);
c = acosh(a);
assert(abs(c.x - acosh(2)) < 1e-12 && abs(c.dx - 1/sqrt(2^2 - 1)) < 1e-12, 'acosh failed');
