% Tests for remove and rm errors

m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.add('c', 'c = beta*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('e', 0);
m.exogenous('x', 0);

% Test 1: remove unknown equation
thrown = false;
try
    m.remove('nonexistent');
catch
    thrown = true;
end
assert(thrown, 'Expected error: unknown equation in remove.');

% Test 2: rm with no arguments
thrown = false;
try
    m.rm();
catch
    thrown = true;
end
assert(thrown, 'Expected error: rm requires at least one argument.');

% Test 3: rm with non-char first argument
thrown = false;
try
    m.rm(123);
catch
    thrown = true;
end
assert(thrown, 'Expected error: first argument must be char.');

% Test 4: rm with non-char arguments (no implicit loops)
thrown = false;
try
    m.rm('y', 42);
catch
    thrown = true;
end
assert(thrown, 'Expected error: all arguments must be char.');
