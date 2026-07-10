% STEADY_STATE operator: accepts an arbitrary expression argument (Dynare
% reference manual), represented as a unary 'ss' node whose child is the
% expression.

% Bare symbol: the child is a 'sym' leaf.
n = ast('STEADY_STATE(GDP)');
assert(strcmp(n.type, 'ss') && isempty(n.value), 'ss node, no value');
assert(isscalar(n.children) && strcmp(n.children{1}.type, 'sym') ...
    && strcmp(n.children{1}.value, 'GDP'), 'ss child is sym GDP');

% Inside a larger expression.
n = ast('alpha * STEADY_STATE(K) + beta');
assert(strcmp(n.value, '+'), 'top is +');
left = n.children{1};
ssnode = left.children{2};
assert(strcmp(ssnode.type, 'ss'), 'right of * is ss');
assert(strcmp(ssnode.children{1}.value, 'K'), 'ss child is K');

% Expression arguments parse and round-trip.
roundtrips = { ...
  'alpha * STEADY_STATE(K) + beta', ...
  'STEADY_STATE(K / GDP)', ...
  'STEADY_STATE(exp(a))', ...
  'log(STEADY_STATE(y / c))', ...
  'STEADY_STATE(K(-1))'};
for i = 1:numel(roundtrips)
    s = roundtrips{i};
    assert(strcmp(ast(s).string(), s), 'ss round-trip: %s -> %s', s, ast(s).string());
end

% symbol_names recurses into the argument (its symbols are referenced as
% steady-state values), matching the getsymbols convention.
syms = sort(ast('STEADY_STATE(K / GDP)').symbol_names());
assert(isequal(syms, {'GDP', 'K'}), 'ss symbol_names recurses into the argument');

% eval: STEADY_STATE(expr) is expr evaluated with the (steady-state) values.
v = struct('k', 6, 'y', 2, 'a', 0);
got = ast('STEADY_STATE(k / y) + STEADY_STATE(exp(a))').eval(v);
assert(abs(got - (6/2 + 1)) < 1e-12, 'ss eval');

% STEADY_STATE(expr) is a constant for differentiation.
d = ast('STEADY_STATE(k) + k').diff_ast('k', 0).string();
assert(strcmp(d, '1'), 'ss is constant under diff: got %s', d);
