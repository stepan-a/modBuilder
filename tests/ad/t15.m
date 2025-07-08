% Test overloaded asin function

a = autoDiff1(0.5, 1);
c = asin(a);
assert(abs(c.x - asin(0.5)) < 1e-12 && abs(c.dx - 1/sqrt(1 - 0.5^2)) < 1e-12, 'asin failed');
