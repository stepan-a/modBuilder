% Tests for parameter declaration errors

% Test 1: Cannot convert endogenous to parameter
m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.parameter('alpha', 0.5);
m.exogenous('e', 0);
m.exogenous('x', 0);

thrown = false;
try
    m.parameter('y', 1.0);
catch
    thrown = true;
end
assert(thrown, 'Expected error: endogenous cannot become parameter.');

% Test 2: Unknown symbol
thrown = false;
try
    m.parameter('nonexistent', 1.0);
catch
    thrown = true;
end
assert(thrown, 'Expected error: unknown symbol.');

% Test 3: validate_type with invalid type
thrown = false;
try
    m.size('badtype');
catch
    thrown = true;
end
assert(thrown, 'Expected error: invalid type string.');
