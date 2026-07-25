% Comparing two models that hold a multi-output steady-state call.
%
% steady_call stores a cellstr in the name column of the steady_state table, which
% sortrows cannot order: comparing any such model raised
% MATLAB:character:CellsMustContainChars instead of answering.

addpath ../utils

m = modBuilder();
m.add('y', 'y = a*k');
m.add('k', 'k = b');
m.exogenous('a', 1);
m.exogenous('b', 1);
m.steady_call({'y', 'k'}, 'someblock(a, b)');

% A model with such a row can be compared at all.
assert(m == m.copy(), 'A model holding a steady_call should equal its copy.');

% The name column is compared, not only the expressions: two models pairing the same
% expression with different names are not equal.
p = modBuilder();
p.add('y', 'y = a*k');
p.add('k', 'k = b');
p.exogenous('a', 1);
p.exogenous('b', 1);
p.steady_call({'k', 'y'}, 'someblock(a, b)');
assert(~(m == p), 'Different output names should not compare equal.');

% Scalar rows keep comparing as before, and their names count too.
q = modBuilder();
q.add('y', 'y = a*k');
q.add('k', 'k = b');
q.exogenous('a', 1);
q.exogenous('b', 1);
q.steady('y', 'a*b');
q.steady('k', 'b');

r = q.copy();
assert(q == r, 'A model with scalar steady-state rows should equal its copy.');

s = modBuilder();
s.add('y', 'y = a*k');
s.add('k', 'k = b');
s.exogenous('a', 1);
s.exogenous('b', 1);
s.steady('y', 'b');
s.steady('k', 'a*b');
assert(~(q == s), 'Swapping which name carries which expression should not compare equal.');

fprintf('eq/t09.m: All tests passed\n');
