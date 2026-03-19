% Test overloaded normcdf function

a = autoDiff1(0, 2);
c = normcdf(a);
assert(abs(c.x - normcdf(0)) < 1e-12, 'normcdf value failed');
assert(abs(c.dx - normpdf(0)*2) < 1e-12, 'normcdf derivative failed');

% Test with non-standard normal (mu=1, sigma=2)
a = autoDiff1(1.5, 1);
c = normcdf(a, 1, 2);
assert(abs(c.x - normcdf(1.5, 1, 2)) < 1e-12, 'normcdf value with mu and sigma failed');
assert(abs(c.dx - normpdf(1.5, 1, 2)) < 1e-12, 'normcdf derivative with sigma ~= 1 failed');
