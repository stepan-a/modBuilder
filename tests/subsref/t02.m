% Tests for subsref: feval path and unknown symbol error

m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 1);

% Test 1: Method call without arguments via dot (feval path, line 4193)
% m.summary without () goes through: typeof('summary') fails → catch →
% isscalar(S) is true → feval('summary', o)
result = m.summary;
assert(isa(result, 'modBuilder'), 'No-arg method via dot should return modBuilder.');

% Test 2: Unknown symbol with chained dot access (line 4201)
% m.unknown.field → S has 2 elements, S(2).type is '.' (not '()')
thrown = false;
try
    m.nonexistent.field;
catch
    thrown = true;
end
assert(thrown, 'Expected error for chained dot on unknown symbol.');
