% Test examples from reassign method documentation

addpath ../utils

% Example 1: Swap
m = modBuilder();
m.add('y', 'y = alpha*k');
m.add('k', 'k = (1-delta)*k(-1) + i');
m.parameter('alpha', 0.33);
m.parameter('delta', 0.025);
m.exogenous('i', 0);

% Swap: y's equation goes to k, k's equation goes to y
m.reassign('y', 'k');

% Verify: y now owns k's old equation, k now owns y's old equation
eq_y = m.equations{strcmp('y', m.equations(:,1)), 2};
eq_k = m.equations{strcmp('k', m.equations(:,1)), 2};
assert(strcmp(eq_y, 'k = (1-delta)*k(-1) + i'), 'y should own k''s old equation after swap');
assert(strcmp(eq_k, 'y = alpha*k'), 'k should own y''s old equation after swap');

fprintf('Example 1 passed: Swap\n');

% Example 2: Three-way cycle
m2 = modBuilder();
m2.add('a', 'a = x + y');
m2.add('b', 'b = y + z');
m2.add('c', 'c = z + x');
m2.exogenous('x', 0);
m2.exogenous('y', 0);
m2.exogenous('z', 0);

% Three-way cycle: a's eq → b, b's eq → c, c's eq → a
m2.reassign('a', 'b', 'c');

% Verify: a owns c's old eq, b owns a's old eq, c owns b's old eq
eq_a = m2.equations{strcmp('a', m2.equations(:,1)), 2};
eq_b = m2.equations{strcmp('b', m2.equations(:,1)), 2};
eq_c = m2.equations{strcmp('c', m2.equations(:,1)), 2};
assert(strcmp(eq_a, 'c = z + x'), 'a should own c''s old equation after cycle');
assert(strcmp(eq_b, 'a = x + y'), 'b should own a''s old equation after cycle');
assert(strcmp(eq_c, 'b = y + z'), 'c should own b''s old equation after cycle');

fprintf('Example 2 passed: Three-way cycle\n');

fprintf('reassign.m: All tests passed\n');
