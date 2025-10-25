% Test examples from change method documentation

m = modBuilder();
m.add('c', 'c = w*h');
m.parameter('w', 1.5);

% Replace the equation for c
m.change('c', 'c = alpha*k + w*h');
m.parameter('alpha', 0.3);

% Verify equation was changed
assert(strcmp(m.equations{1,2}, 'c = alpha*k + w*h'));
assert(m.size('parameters') == 2);

fprintf('change.m: All tests passed\n');
