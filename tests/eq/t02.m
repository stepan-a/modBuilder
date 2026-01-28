% Tests for eq method: non-modBuilder comparison (error branch)

m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 0);

% Test 1: Compare with numeric
thrown = false;
try
    m == 42;
catch
    thrown = true;
end
assert(thrown, 'Expected error: cannot compare with numeric.');

% Test 2: Compare with string
thrown = false;
try
    m == 'hello';
catch
    thrown = true;
end
assert(thrown, 'Expected error: cannot compare with string.');

% Test 3: Compare with struct
thrown = false;
try
    m == struct('a', 1);
catch
    thrown = true;
end
assert(thrown, 'Expected error: cannot compare with struct.');
