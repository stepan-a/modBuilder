% Test overloaded tanh function

a = autoDiff1(0.5, 2);
c = tanh(a);
assert(abs(c.x - tanh(0.5)) < 1e-12 && abs(c.dx - 2*(1 - tanh(0.5)^2)) < 1e-12, 'tanh failed');
