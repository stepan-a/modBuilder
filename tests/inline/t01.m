addpath ../utils

% inline: replace a parameter by its calibration value across all equations.

m = modBuilder();
m.add('y', 'y = alpha*k + beta*h');
m.parameter('alpha', 0.33);
m.parameter('beta', 0.67);
m.exogenous('k', 1.0);
m.exogenous('h', 1.0);

m.inline('alpha', '0.33');

% Verify the equation has alpha replaced by the literal 0.33 (compare via AST so
% whitespace and rendering choices do not matter).
got = m{'y'}.equations{2};
LHSRHS = strsplit(got, '=');
got_rhs = ast(strtrim(LHSRHS{2}));
expected_rhs = ast('0.33*k + beta*h');
if not(ast.ast_equal(got_rhs, expected_rhs))
    error('inline: RHS mismatch. expected "%s", got "%s"', expected_rhs.string(), got_rhs.string())
end

% alpha is no longer referenced by any equation and must have been dropped.
if m.issymbol('alpha')
    error('alpha should be removed after inline')
end

% beta is still referenced; it must still be a parameter.
if not(m.isparameter('beta'))
    error('beta should still be a parameter')
end

fprintf('t01.m: All tests passed\n');
