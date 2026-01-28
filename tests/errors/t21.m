% Tests for autoDiff1 trigonometric domain errors

% Test 1: tan at asymptote
thrown = false;
try
    tan(autoDiff1(pi/2, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: tan at asymptote.');

% Test 2: asin out of domain
thrown = false;
try
    asin(autoDiff1(1.5, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: asin domain error (>1).');

thrown = false;
try
    asin(autoDiff1(-1.5, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: asin domain error (<-1).');

thrown = false;
try
    asin(autoDiff1(1.0, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: asin at boundary.');

% Test 3: acos out of domain
thrown = false;
try
    acos(autoDiff1(2.0, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: acos domain error.');
