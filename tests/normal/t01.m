% Tests for normcdf (normal cumulative distribution function)

tol = 1e-10;

% Test 1: Standard normal at origin
assert(abs(normcdf(0) - 0.5) < tol, 'normcdf(0) should be 0.5.');

% Test 2: Limits
assert(normcdf(-1e15) < tol, 'normcdf(-Inf) should approach 0.');
assert(abs(normcdf(1e15) - 1) < tol, 'normcdf(+Inf) should approach 1.');

% Test 3: Known quantiles (standard normal)
assert(abs(normcdf(1.959963984540054) - 0.975) < 1e-6, 'normcdf(1.96) should be ~0.975.');
assert(abs(normcdf(-1.959963984540054) - 0.025) < 1e-6, 'normcdf(-1.96) should be ~0.025.');
assert(abs(normcdf(1) - 0.841344746068543) < tol, 'normcdf(1) should be ~0.8413.');
assert(abs(normcdf(-1) - 0.158655253931457) < tol, 'normcdf(-1) should be ~0.1587.');

% Test 4: Symmetry: normcdf(-x) = 1 - normcdf(x)
x = [0.5, 1.0, 2.0, 3.0];
assert(all(abs(normcdf(-x) - (1 - normcdf(x))) < tol), 'normcdf should satisfy symmetry.');

% Test 5: Monotonicity
x = -3:0.5:3;
p = normcdf(x);
assert(all(diff(p) > 0), 'normcdf should be monotonically increasing.');

% Test 6: With mu argument (sigma defaults to 1)
assert(abs(normcdf(5, 5) - 0.5) < tol, 'normcdf(mu, mu) should be 0.5.');
assert(abs(normcdf(7, 5) - normcdf(2)) < tol, 'Shifting by mu should match standard normal.');

% Test 7: With mu and sigma arguments
assert(abs(normcdf(10, 10, 3) - 0.5) < tol, 'normcdf(mu, mu, sigma) should be 0.5.');
assert(abs(normcdf(13, 10, 3) - normcdf(1)) < tol, 'normcdf with sigma should scale correctly.');

% Test 8: Vectorized input
x = [-2, -1, 0, 1, 2];
p = normcdf(x);
assert(numel(p) == 5, 'normcdf should handle vector input.');
assert(abs(p(3) - 0.5) < tol, 'Vector output: normcdf(0) should be 0.5.');
