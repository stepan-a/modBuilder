% Tests for tag errors

m = modBuilder();
m.add('y_1', 'y_1 = a_1*x_1');
m.add('y_2', 'y_2 = a_2*x_2');
m.parameter('a_1', 0.5);
m.parameter('a_2', 0.5);
m.exogenous('x_1', 0);
m.exogenous('x_2', 0);

% Test 1: Mismatched index count in tag
thrown = false;
try
    m.tag('y_$1_$2', 'desc', 'Production', {1, 2});
catch
    thrown = true;
end
assert(thrown, 'Expected error: mismatched index count in tag.');

% Test 2: Tag with implicit loops (valid usage)
m.tag('y_$1', 'sector', 'manufacturing', {1, 2});
assert(true, 'Tag with implicit loops should succeed.');
