addpath ../utils

% Test interaction with merge()

m1 = modBuilder();
m1.add('y', 'y = a*k');
m1.parameter('a', 0.33);
m1.exogenous('k', 1.0);
m1.steady('y', 'a*k');

m2 = modBuilder();
m2.add('c', 'c = b*h');
m2.parameter('b', 0.5);
m2.exogenous('h', 1.0);
m2.steady('c', 'b*h');

q = m1.merge(m2);

if size(q.steady_state, 1) ~= 2
    error('Merged model should have 2 steady-state expressions')
end

% Verify both expressions are present
names = q.steady_state(:, 1)';
if ~ismember('y', names)
    error('Merged model should have y steady-state expression')
end
if ~ismember('c', names)
    error('Merged model should have c steady-state expression')
end

fprintf('t10.m: All tests passed\n');
