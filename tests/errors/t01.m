% Tests for validate_equation_syntax errors

m = modBuilder();

% Test 1: Unbalanced parentheses
thrown = false;
try
    m.add('y', 'y = a*(x(-1) + b');
catch
    thrown = true;
end
assert(thrown, 'Expected error for unbalanced parentheses.');

% Test 2: Double equals
thrown = false;
try
    m.add('y', 'y == x');
catch
    thrown = true;
end
assert(thrown, 'Expected error for == in equation.');

% Test 3: Element-wise division
thrown = false;
try
    m.add('y', 'y = x./z');
catch
    thrown = true;
end
assert(thrown, 'Expected error for ./ in equation.');

% Test 4: ++ warning
lastwarn('');
m.add('y', 'y = x ++ z');
[msg, ~] = lastwarn();
assert(contains(msg, '++'), 'Expected warning for ++ in equation.');
m.remove('y');

% Test 5: -- warning
lastwarn('');
m.add('y', 'y = x -- z');
[msg, ~] = lastwarn();
assert(contains(msg, '--'), 'Expected warning for -- in equation.');
