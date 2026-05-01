addpath ../utils

% inline: when eqname is provided, only that equation is rewritten.

m = modBuilder();
m.add('y1', 'y1 = alpha + 1');
m.add('y2', 'y2 = alpha + 2');
m.parameter('alpha', 0.5);

m.inline('alpha', '0.5', 'y1');

got1 = m{'y1'}.equations{2};
LHSRHS = strsplit(got1, '=');
got1_rhs = ast(strtrim(LHSRHS{2}));
if not(ast.ast_equal(got1_rhs, ast('0.5 + 1')))
    error('y1 inline failed: got "%s"', got1_rhs.string())
end

got2 = m{'y2'}.equations{2};
LHSRHS = strsplit(got2, '=');
got2_rhs = ast(strtrim(LHSRHS{2}));
if not(ast.ast_equal(got2_rhs, ast('alpha + 2')))
    error('y2 should not have been touched: got "%s"', got2_rhs.string())
end

% alpha still appears in y2, so it must remain a parameter
if not(m.isparameter('alpha'))
    error('alpha should still be a parameter (still referenced by y2)')
end

fprintf('t03.m: All tests passed\n');
