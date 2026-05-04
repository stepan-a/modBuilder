addpath ../utils

% subs: precedence is preserved through substitution, fixing the strrep bug.
% Substituting x by p+q in a*x^2 must yield a*(p+q)^2, not the buggy a*p+q^2.

m = modBuilder();
m.add('y', 'y = a * x^2');
m.exogenous('a', 1);
m.exogenous('x', 1);

m.subs('x', 'p + q');

got = m{'y'}.equations{2};
LHSRHS = strsplit(got, '=');
got_rhs = ast(strtrim(LHSRHS{2}));
expected_rhs = ast('a * (p + q)^2');
if not(ast.ast_equal(got_rhs, expected_rhs))
    error('subs: precedence not preserved. expected "%s", got "%s"', expected_rhs.string(), got_rhs.string())
end

fprintf('t04.m: All tests passed\n');
