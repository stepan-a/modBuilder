% Tests for subsref and subsasgn errors

m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.parameter('alpha', 0.5);
m.exogenous('e', 0);
m.exogenous('x', 0);

% --- subsasgn errors ---

% Test 1: Multi-level assignment
thrown = false;
try
    m.alpha.x = 5;
catch
    thrown = true;
end
assert(thrown, 'Expected error: multi-level assignment.');

% Test 2: Non-scalar assignment via dot
thrown = false;
try
    m.alpha = [1 2];
catch
    thrown = true;
end
assert(thrown, 'Expected error: non-scalar assignment.');

% Test 3: Unknown symbol in dot assignment
thrown = false;
try
    m.nonexistent = 5.0;
catch
    thrown = true;
end
assert(thrown, 'Expected error: unknown symbol in dot assignment.');

% Test 4: Non-char index in paren assignment
thrown = false;
try
    m(123) = 'y = x';
catch
    thrown = true;
end
assert(thrown, 'Expected error: non-char index in paren assignment.');

% Test 5: Non-endogenous in paren assignment
thrown = false;
try
    m('alpha') = 'alpha = 0.5';
catch
    thrown = true;
end
assert(thrown, 'Expected error: cannot change equation for non-endogenous.');

% Test 6: Non-char equation assignment
thrown = false;
try
    m('y') = 42;
catch
    thrown = true;
end
assert(thrown, 'Expected error: non-char equation assignment.');

% Test 7: Curly brace assignment
thrown = false;
try
    m{'y'} = 'y = x';
catch
    thrown = true;
end
assert(thrown, 'Expected error: cannot assign with curly braces.');

% --- subsref: dot access for symbol values ---

% Test 8: Access parameter value via dot notation
val = m.alpha;
assert(val == 0.5, 'Dot access should return parameter value.');

% Test 9: Access exogenous value via dot notation
val = m.e;
assert(val == 0, 'Dot access should return exogenous value.');

% Test 10: Valid scalar assignment via dot notation
m.alpha = 0.9;
assert(m.params{1,2} == 0.9, 'Dot assignment should update parameter value.');
