% Test examples from rename method documentation

m = modBuilder();
m.add('c', 'c = alpha*k');
m.parameter('alpha', 0.33);
m.updatesymboltables();

% Rename parameter
m.rename('alpha', 'beta');
assert(any(strcmp(m.params(:,1), 'beta')));
assert(~any(strcmp(m.params(:,1), 'alpha')));

% Rename endogenous variable
m.rename('c', 'consumption');
assert(any(strcmp(m.var(:,1), 'consumption')));
assert(~any(strcmp(m.var(:,1), 'c')));
assert(strcmp(m.equations{1,1}, 'consumption'));

fprintf('rename.m: All tests passed\n');
