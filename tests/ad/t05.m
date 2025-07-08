% Test overloaded rdivide (/) method

a = autoDiff1(8, 2);
b = autoDiff1(2, 1);
c = a / b;
expected_dx = (2*2 - 1*8)/(2^2);
assert(c.x == 4 && abs(c.dx - expected_dx) < 1e-12, '/ operator failed');
