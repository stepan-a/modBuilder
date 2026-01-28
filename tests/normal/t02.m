% Tests for normpdf (normal probability density function)

tol = 1e-10;

% Test 1: Standard normal at origin
expected = 1 / sqrt(2*pi);
assert(abs(normpdf(0) - expected) < tol, 'normpdf(0) should be 1/sqrt(2*pi).');

% Test 2: Known values (standard normal)
assert(abs(normpdf(1) - exp(-0.5)/sqrt(2*pi)) < tol, 'normpdf(1) mismatch.');
assert(abs(normpdf(2) - exp(-2)/sqrt(2*pi)) < tol, 'normpdf(2) mismatch.');

% Test 3: Symmetry: normpdf(-x) = normpdf(x)
x = [0.5, 1.0, 2.0, 3.0];
assert(all(abs(normpdf(-x) - normpdf(x)) < tol), 'normpdf should be symmetric.');

% Test 4: Non-negative and unimodal
x = -4:0.1:4;
y = normpdf(x);
assert(all(y >= 0), 'normpdf should be non-negative.');
[~, idx] = max(y);
assert(abs(x(idx)) < 0.15, 'Standard normal mode should be at 0.');

% Test 5: Tails approach zero
assert(normpdf(10) < 1e-20, 'normpdf should vanish in the tails.');
assert(normpdf(-10) < 1e-20, 'normpdf should vanish in the tails.');

% Test 6: With mu argument (sigma defaults to 1)
assert(abs(normpdf(5, 5) - expected) < tol, 'normpdf(mu, mu) should equal normpdf(0).');
assert(abs(normpdf(7, 5) - normpdf(2)) < tol, 'Shifting by mu should match standard normal.');

% Test 7: With mu and sigma arguments
expected_sigma3 = 1 / (sqrt(2*pi) * 3);
assert(abs(normpdf(10, 10, 3) - expected_sigma3) < tol, 'normpdf(mu, mu, sigma) should be 1/(sqrt(2*pi)*sigma).');
assert(abs(normpdf(13, 10, 3) - exp(-0.5)/(sqrt(2*pi)*3)) < tol, 'normpdf with sigma should scale correctly.');

% Test 8: Vectorized input
x = [-2, -1, 0, 1, 2];
y = normpdf(x);
assert(numel(y) == 5, 'normpdf should handle vector input.');
assert(abs(y(3) - expected) < tol, 'Vector output: normpdf(0) should be 1/sqrt(2*pi).');
assert(abs(y(2) - y(4)) < tol, 'Symmetry check in vector output.');
