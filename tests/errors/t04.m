% Tests for endogenous declaration errors

m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 0);

% Test 1: Symbol is not endogenous (it's a parameter)
thrown = false;
try
    m.endogenous('alpha');
catch
    thrown = true;
end
assert(thrown, 'Expected error: symbol is not endogenous.');

% Test 2: Symbol is not endogenous (it's exogenous)
thrown = false;
try
    m.endogenous('x');
catch
    thrown = true;
end
assert(thrown, 'Expected error: exogenous is not endogenous.');
