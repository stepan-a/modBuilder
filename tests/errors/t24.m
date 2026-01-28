% Tests for autoDiff1 erf and erfc

% Test 1: erf
x = autoDiff1(0.5, 1);
q = erf(x);
assert(abs(q.x - erf(0.5)) < 1e-10, 'erf: value');
expected_dx = (2.0/sqrt(pi)) * exp(-0.25);
assert(abs(q.dx - expected_dx) < 1e-10, 'erf: derivative');

% Test 2: erfc
q = erfc(x);
assert(abs(q.x - erfc(0.5)) < 1e-10, 'erfc: value');
assert(abs(q.dx - (-expected_dx)) < 1e-10, 'erfc: derivative');

% Test 3: erf at zero
x = autoDiff1(0, 1);
q = erf(x);
assert(abs(q.x) < 1e-10, 'erf(0) should be 0.');
assert(abs(q.dx - 2.0/sqrt(pi)) < 1e-10, 'erf''(0) = 2/sqrt(pi).');
