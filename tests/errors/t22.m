% Tests for autoDiff1 hyperbolic domain errors

% Test 1: acosh with argument <= 1
thrown = false;
try
    acosh(autoDiff1(0.5, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: acosh domain error.');

thrown = false;
try
    acosh(autoDiff1(1.0, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: acosh at boundary.');

% Test 2: atanh with |argument| >= 1
thrown = false;
try
    atanh(autoDiff1(1.5, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: atanh domain error (>1).');

thrown = false;
try
    atanh(autoDiff1(-1.0, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: atanh at boundary.');
