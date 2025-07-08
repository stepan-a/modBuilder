% Test overloaded plus method

a = autoDiff1(2, 1);
b = autoDiff1(5, 2);
c = a + b;
assert(c.x == 7 && c.dx == 3, '+ operator failed');
