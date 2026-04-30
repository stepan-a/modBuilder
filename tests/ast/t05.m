% STEADY_STATE operator

n = ast('STEADY_STATE(GDP)');
assert(strcmp(n.type, 'ss') && strcmp(n.value, 'GDP'), 'ss node');
assert(isempty(n.children), 'ss has no children');

% Inside a larger expression
n = ast('alpha * STEADY_STATE(K) + beta');
assert(strcmp(n.value, '+'), 'top is +');
left = n.children{1};
assert(strcmp(left.children{2}.type, 'ss'), 'right of * is ss');
assert(strcmp(left.children{2}.value, 'K'), 'ss name is K');

% Round-trip
s = 'alpha * STEADY_STATE(K) + beta';
assert(strcmp(ast(s).string(), s), 'ss round-trip');
