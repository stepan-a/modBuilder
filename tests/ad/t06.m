% Test overloaded mpower (^) method

a = autoDiff1(2, 1);
c = a^3;
assert(abs(c.x - 8) < 1e-12 && abs(c.dx - 3*4) < 1e-12, '^ operator (numeric exponent) failed');
