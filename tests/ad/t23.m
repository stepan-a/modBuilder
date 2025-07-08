% Test overloaded atanh function

a = autoDiff1(0.5, 1);
c = atanh(a);
assert(abs(c.x - atanh(0.5)) < 1e-12 && abs(c.dx - 1/(1 - 0.5^2)) < 1e-12, 'atanh failed');
