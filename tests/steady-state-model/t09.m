addpath ../utils

% Test interaction with copy() and extract()

m = modBuilder();

m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
m.add('k', '1/beta = alpha*y(+1)/k + (1-delta)');
m.parameter('alpha', 0.36);
m.parameter('beta', 0.99);
m.parameter('delta', 0.025);

m.steady('k', '(alpha*beta/(1-beta*(1-delta)))^(1/(1-alpha))');
m.steady('y', 'k^alpha');
m.steady('c', 'y - delta*k');

% Test copy
m2 = m.copy();

if ~isequal(m2.steady_state, m.steady_state)
    error('copy() should preserve steady_state')
end

% Modify original, verify copy is independent
m.steady('y', 'k^(alpha+1)');
if isequal(m2.steady_state{2, 2}, m.steady_state{2, 2})
    error('copy() should create independent copy')
end

% Test extract (uses copy + rm internally)
m3 = m2.extract('y', 'k');

% y's steady expression should remain, c's should be removed (c was extracted away)
found_y = false;
found_c = false;
for i = 1:size(m3.steady_state, 1)
    if strcmp(m3.steady_state{i, 1}, 'y')
        found_y = true;
    end
    if strcmp(m3.steady_state{i, 1}, 'c')
        found_c = true;
    end
end

if ~found_y
    error('extract() should preserve y steady-state expression')
end

if found_c
    error('extract() should have removed c steady-state expression')
end

fprintf('t09.m: All tests passed\n');
