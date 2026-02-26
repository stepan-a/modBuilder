addpath ../utils

% Test implicit loops: steady('Y_$1', 'A_$1*K_$1', {1,2,3})

m = modBuilder();

m.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
m.parameter('A_$1', 1.0, {1, 2, 3});
m.exogenous('K_$1', 1.0, {1, 2, 3});

m.steady('Y_$1', 'A_$1*K_$1', {1, 2, 3});

m.write('t05', steady_state_model=true);

b = modiff('t05.mod', 't05.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete t05.mod
end

fprintf('t05.m: All tests passed\n');
