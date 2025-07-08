% Test overloaded normcdf function

if ~license('test', 'Statistics_Toolbox');
    addpath ../../src/missing/stats
end

a = autoDiff1(0, 2);
c = normcdf(a);
assert(abs(c.x - normcdf(0)) < 1e-12, 'normcdf value failed');
assert(abs(c.dx - normpdf(0)*2) < 1e-12, 'normcdf derivative failed');
