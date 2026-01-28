% Tests for evaluate() method branches

m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.add('c', 'c = beta*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('e', 0);
m.exogenous('x', 2);
m.endogenous('y', 1.0);
m.endogenous('c', 0.8);

% Test 1: Evaluate with printflag=true and positive residual (line 4024)
% y = alpha*x + e => LHS=1.0, RHS=0.5*2+0=1.0, resid=0.0 (non-negative)
evaleq = m.evaluate('y', true);
assert(abs(evaleq.resid) < 1e-10, 'Residual for y should be ~0.');

% Test 2: Evaluate with negative residual (line 4022)
% c = beta*y => LHS=0.8, RHS=0.8*1.0=0.8, resid=0.0
% Force negative: set c to 0.5 so LHS=0.5 < RHS=0.8
m.endogenous('c', 0.5);
evaleq = m.evaluate('c', true);
assert(evaleq.resid < 0, 'Residual for c should be negative.');

% Test 3: Evaluate without printing (default)
evaleq = m.evaluate('y');
assert(isstruct(evaleq), 'evaluate should return a struct.');
assert(isfield(evaleq, 'lhs'), 'Struct should have lhs field.');
assert(isfield(evaleq, 'rhs'), 'Struct should have rhs field.');
assert(isfield(evaleq, 'resid'), 'Struct should have resid field.');
