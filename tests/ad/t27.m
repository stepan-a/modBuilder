% Test overloaded normpdf function

if ~license('test', 'Statistics_Toolbox');
    addpath ../../src/missing/stats
end

a = autoDiff1(0, 2);
c = normpdf(a);
assert(abs(c.x - normpdf(0)) < 1e-12, 'normpdf value failed');
assert(abs(c.dx + 0*normpdf(0)*2) < 1e-12, 'normpdf derivative failed');
