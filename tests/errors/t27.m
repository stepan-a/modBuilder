% Tests for rename exogenous (uncovered code path)

m = modBuilder();
m.add('y', 'y = alpha*x + epsilon');
m.parameter('alpha', 0.5);
m.exogenous('epsilon', 0);
m.exogenous('x', 0);

% Test 1: Rename exogenous variable
assert(m.isexogenous('epsilon'), 'epsilon should be exogenous.');
m.rename('epsilon', 'e');
assert(m.isexogenous('e'), 'e should be exogenous after rename.');
assert(~m.isexogenous('epsilon'), 'epsilon should no longer exist.');
assert(strcmp(m.equations{1,2}, 'y = alpha*x + e'), 'Equation should use new name.');
