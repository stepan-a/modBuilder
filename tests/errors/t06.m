% Tests for check_indices_values errors

m = modBuilder();

% Test 1: Mixed types in index values (integers and strings)
thrown = false;
try
    m.add('y_$1', 'y_$1 = x_$1', {1, 'a'});
catch
    thrown = true;
end
assert(thrown, 'Expected error: mixed types in index values.');

% Test 2: Non-vector cell array
thrown = false;
try
    m.add('y_$1', 'y_$1 = x_$1', {1, 2; 3, 4});
catch
    thrown = true;
end
assert(thrown, 'Expected error: non-vector cell array for index values.');

% Test 3: Non-cell argument for index values
thrown = false;
try
    m.add('y_$1', 'y_$1 = x_$1', 'notacell');
catch
    thrown = true;
end
assert(thrown, 'Expected error: non-cell argument for index values.');
