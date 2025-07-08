% Test overloaded log10 function

a = autoDiff1(10, 4);
c = log10(a);
assert(abs(c.x - 1) < 1e-12 && abs(c.dx - 4/(10*log(10))) < 1e-12, 'log10 failed');
