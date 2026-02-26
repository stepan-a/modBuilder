addpath ../utils

% Test interaction with flip(): steady expression removed for exogenised variable

m = modBuilder();

m.add('y', 'y = a*k');
m.parameter('a', 0.33);
m.exogenous('k', 1.0);

m.steady('y', 'a*k');

% Verify expression exists
if size(m.steady_state, 1) ~= 1
    error('Should have 1 steady-state expression before flip')
end

% Flip y and k: y becomes exogenous
m.flip('y', 'k');

% Verify y's steady expression was removed (y is now exogenous)
if size(m.steady_state, 1) ~= 0
    error('Should have 0 steady-state expressions after flip')
end

fprintf('t08.m: All tests passed\n');
