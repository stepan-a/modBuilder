addpath ../utils

% Test interaction with remove(): steady expression removed with equation

m = modBuilder();

m.add('y', 'y = alpha*k');
m.add('c', 'c = y - delta*k');
m.parameter('alpha', 0.36);
m.parameter('delta', 0.025);
m.exogenous('k', 1);

m.steady('y', 'alpha*k');
m.steady('c', 'y - delta*k');

% Verify both expressions exist
if size(m.steady_state, 1) ~= 2
    error('Should have 2 steady-state expressions before remove')
end

% Remove equation for c
m.remove('c');

% Verify c's steady expression was removed
if size(m.steady_state, 1) ~= 1
    error('Should have 1 steady-state expression after remove')
end

if ~strcmp(m.steady_state{1, 1}, 'y')
    error('Remaining expression should be for y')
end

fprintf('t06.m: All tests passed\n');
