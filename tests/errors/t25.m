% Tests for bytag constructor error

% Test 1: Odd number of arguments
thrown = false;
try
    bytag('sector');
catch
    thrown = true;
end
assert(thrown, 'Expected error: bytag requires name-value pairs.');

% Test 2: Valid usage
b = bytag('sector', 'manufacturing');
assert(isa(b, 'bytag'), 'bytag constructor should work with pairs.');
