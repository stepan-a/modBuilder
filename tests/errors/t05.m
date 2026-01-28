% Tests for add/addeq errors

m = modBuilder();

% Test 1: Duplicate equation
m.add('y', 'y = x');
thrown = false;
try
    m.add('y', 'y = z');
catch
    thrown = true;
end
assert(thrown, 'Expected error: duplicate equation for variable.');

% Test 2: Index count mismatch (equation has more indices than provided)
m2 = modBuilder();
thrown = false;
try
    m2.add('y_$1', 'y_$1 = x_$1 + z_$2', {1, 2});
catch
    thrown = true;
end
assert(thrown, 'Expected error: index count mismatch.');

% Test 3: Indices mismatch between varname and equation
m3 = modBuilder();
thrown = false;
try
    m3.add('y_$1', 'y_$2 = x_$2', {1, 2});
catch
    thrown = true;
end
assert(thrown, 'Expected error: indices mismatch between varname and equation.');
