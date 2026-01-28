% Tests for summary() edge cases

% Test 1: Model with no parameters (line 2748)
m = modBuilder();
m.add('y', 'y = x');
m.exogenous('x', 0);
m.summary();
% No assertion needed: this exercises the "Parameters: 0" branch.
% If it errors, the test fails.

% Test 2: Model with untyped symbols (line 2756)
m2 = modBuilder();
m2.add('y', 'y = alpha*x + e');
m2.parameter('alpha', 0.5);
% x and e remain untyped
m2.summary();
% This exercises the "Warning: N untyped symbol(s)" branch.
