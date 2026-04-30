% Function calls

n = ast('exp(x)');
assert(strcmp(n.type, 'call') && strcmp(n.value, 'exp'), 'exp call');
assert(numel(n.children) == 1 && strcmp(n.children{1}.value, 'x'), 'one arg');

n = ast('log(a + b)');
assert(strcmp(n.type, 'call') && strcmp(n.value, 'log'), 'log call');
assert(strcmp(n.children{1}.value, '+'), 'arg is binop');

% Multi-arg call
n = ast('max(a, b)');
assert(strcmp(n.type, 'call') && strcmp(n.value, 'max'), 'max call');
assert(numel(n.children) == 2, 'two args');

% Nested calls
n = ast('exp(log(x))');
assert(strcmp(n.type, 'call') && strcmp(n.value, 'exp'), 'outer exp');
assert(strcmp(n.children{1}.type, 'call') && strcmp(n.children{1}.value, 'log'), 'inner log');

% Reserved name not followed by ( is a bare symbol (degenerate but consistent)
n = ast('exp');
assert(strcmp(n.type, 'sym') && strcmp(n.value, 'exp'), 'bare reserved name is sym');
