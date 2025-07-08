% Test overload exp function

a = autoDiff1(1, 2);
c = exp(a);
assert(abs(c.x - exp(1)) < 1e-12 && abs(c.dx - exp(1)*2) < 1e-12, 'exp failed');
