% Test examples from copy method documentation

m = modBuilder();
m.add('c', 'c = alpha*k');
m.parameter('alpha', 0.33);

% Create a copy to experiment with
m2 = m.copy();
m2.change('c', 'c = beta*k');
m2.parameter('beta', 0.5);

% Original m is unchanged
assert(strcmp(m.equations{1,2}, 'c = alpha*k'));
assert(m.size('parameters') == 1);
assert(any(strcmp(m.params(:,1), 'alpha')));

% m2 has the changes
assert(strcmp(m2.equations{1,2}, 'c = beta*k'));
assert(m2.size('parameters') == 1);  % Only beta, alpha was removed
assert(strcmp(m2.params{1,1}, 'beta'));

fprintf('copy.m: All tests passed\n');
