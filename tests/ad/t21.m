% Test overloaded asinh function

a = autoDiff1(1, 1);
c = asinh(a);
assert(abs(c.x - asinh(1)) < 1e-12 && abs(c.dx - 1/sqrt(1 + 1^2)) < 1e-12, 'asinh failed');
