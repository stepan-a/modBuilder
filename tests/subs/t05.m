addpath ../utils

% subs: word-boundary safety. Substituting "k" must not touch "k_bar".

m = modBuilder();
m.add('y', 'y = k_bar + k');
m.exogenous('k_bar', 1);
m.exogenous('k', 1);

m.subs('k', 'p + q');

got = m{'y'}.equations{2};
LHSRHS = strsplit(got, '=');
got_rhs = ast(strtrim(LHSRHS{2}));
expected_rhs = ast('k_bar + (p + q)');
if not(ast.ast_equal(got_rhs, expected_rhs))
    error('subs: word boundary violated. expected "%s", got "%s"', expected_rhs.string(), got_rhs.string())
end

% k_bar must still be exogenous (it was untouched)
if not(m.isexogenous('k_bar'))
    error('k_bar should still be exogenous')
end

% k is gone from any equation, so it must have been removed
if m.issymbol('k')
    error('k should be removed after subs')
end

fprintf('t05.m: All tests passed\n');
