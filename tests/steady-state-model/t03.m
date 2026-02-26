addpath ../utils

% Test tie-breaking: independent variables preserve steady() call order

m = modBuilder();

m.add('x', 'x = a + e_x');
m.add('y', 'y = b + e_y');
m.add('z', 'z = c + e_z');
m.parameter('a', 1);
m.parameter('b', 2);
m.parameter('c', 3);
m.exogenous('e_x', 0);
m.exogenous('e_y', 0);
m.exogenous('e_z', 0);

% All independent, order should be preserved
m.steady('z', 'c');
m.steady('x', 'a');
m.steady('y', 'b');

m.write('t03', steady_state_model=true);

b = modiff('t03.mod', 't03.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete t03.mod
end

fprintf('t03.m: All tests passed\n');
