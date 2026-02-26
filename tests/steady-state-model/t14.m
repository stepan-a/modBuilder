addpath ../utils

% Test replacing an existing expression with a second steady() call

m = modBuilder();

m.add('y', 'y = k^alpha');
m.parameter('alpha', 0.36);
m.exogenous('k', 1.0);

m.steady('y', 'k^alpha');

% Verify initial expression
if ~strcmp(m.steady_state{1, 2}, 'k^alpha')
    error('Initial expression should be k^alpha')
end

% Replace expression
m.steady('y', 'alpha*k');

% Verify replacement
if size(m.steady_state, 1) ~= 1
    error('Should still have exactly 1 expression after replacement')
end

if ~strcmp(m.steady_state{1, 2}, 'alpha*k')
    error('Expression should be replaced to alpha*k')
end

fprintf('t14.m: All tests passed\n');
