% Tests for autoDiff1 domain errors: log, log10, sqrt, cbrt

% Test 1: log of non-positive
thrown = false;
try
    log(autoDiff1(0, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: log domain error.');

thrown = false;
try
    log(autoDiff1(-1, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: log of negative.');

% Test 2: log10 of non-positive
thrown = false;
try
    log10(autoDiff1(-1, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: log10 domain error.');

% Test 3: sqrt of non-positive
thrown = false;
try
    sqrt(autoDiff1(-1, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: sqrt domain error.');

thrown = false;
try
    sqrt(autoDiff1(0, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: sqrt of zero.');

% Test 4: cbrt of zero
thrown = false;
try
    cbrt(autoDiff1(0, 1));
catch
    thrown = true;
end
assert(thrown, 'Expected error: cbrt domain error.');
