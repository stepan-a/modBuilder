% Test overloaded minus method

a = autoDiff1(7, 3);
b = autoDiff1(4, 1);
c = a - b;
assert(c.x == 3 && c.dx == 2, '- operator failed');
