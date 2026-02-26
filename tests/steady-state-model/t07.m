addpath ../utils

% Test interaction with rename(): symbol name and expression content updated

m = modBuilder();

m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
m.parameter('alpha', 0.36);
m.parameter('delta', 0.025);
m.exogenous('k', 1);

m.steady('y', 'k^alpha');
m.steady('c', 'y - delta*k');

% Rename endogenous variable y to output
m.rename('y', 'output');

% Check that steady_state name was updated
if ~strcmp(m.steady_state{1, 1}, 'output')
    error('Steady-state name should be updated from y to output')
end

% Check that steady_state expression for c was updated
if ~strcmp(m.steady_state{2, 2}, 'output - delta*k')
    error('Steady-state expression for c should reference output instead of y, got: %s', m.steady_state{2, 2})
end

% Rename parameter
m.rename('alpha', 'a');

% Check that expression for output was updated
if ~strcmp(m.steady_state{1, 2}, 'k^a')
    error('Steady-state expression for output should reference a instead of alpha, got: %s', m.steady_state{1, 2})
end

fprintf('t07.m: All tests passed\n');
