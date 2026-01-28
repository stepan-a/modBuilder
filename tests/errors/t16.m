% Tests for handle_implicit_loops errors

% Test 1: Key without value
m = modBuilder();
m.add('y_1', 'y_1 = p_1*x_1');
m.add('y_2', 'y_2 = p_2*x_2');
m.exogenous('x_1', 0);
m.exogenous('x_2', 0);
thrown = false;
try
    m.parameter('p_$1', 1.0, {1, 2}, 'long_name');
catch
    thrown = true;
end
assert(thrown, 'Expected error: key without value.');

% Test 2: Unexpected argument type (numeric instead of key/cell)
m2 = modBuilder();
m2.add('y_1', 'y_1 = q_1*x_1');
m2.add('y_2', 'y_2 = q_2*x_2');
m2.exogenous('x_1', 0);
m2.exogenous('x_2', 0);
thrown = false;
try
    m2.parameter('q_$1', 1.0, 42, {1, 2});
catch
    thrown = true;
end
assert(thrown, 'Expected error: unexpected argument type.');

% Test 3: Index count mismatch (2 placeholders, 1 index array)
m3 = modBuilder();
m3.add('y_1', 'y_1 = r_1_1*x_1');
thrown = false;
try
    m3.parameter('r_$1_$2', 1.0, {1, 2});
catch
    thrown = true;
end
assert(thrown, 'Expected error: index count mismatch.');
