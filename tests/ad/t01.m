% Constructor test

x = autoDiff1(3);
assert(isa(x, 'autoDiff1') && x.x == 3 && x.dx == 1, 'Constructor test failed');
