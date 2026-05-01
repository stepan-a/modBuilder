addpath ../utils

% inline: implicit loop with shared placeholder between varname/replacement and eqname.

m = modBuilder();
m.add('Y_1', 'Y_1 = alpha_1 * K_1');
m.add('Y_2', 'Y_2 = alpha_2 * K_2');
m.parameter('alpha_$1', 0.3, {1, 2});
m.exogenous('K_$1', 1.0, {1, 2});

% Inline alpha_i by beta_i in equation Y_i (same index). beta_i is a new symbol;
% it will land in the untyped pool with a warning.
warning('off', 'backtrace')
m.inline('alpha_$1', 'beta_$1', 'Y_$1', {1, 2});
warning('on', 'backtrace')

got1 = m{'Y_1'}.equations{2};
LHSRHS = strsplit(got1, '=');
got1_rhs = ast(strtrim(LHSRHS{2}));
if not(ast.ast_equal(got1_rhs, ast('beta_1 * K_1')))
    error('Y_1 inline failed: got "%s"', got1_rhs.string())
end

got2 = m{'Y_2'}.equations{2};
LHSRHS = strsplit(got2, '=');
got2_rhs = ast(strtrim(LHSRHS{2}));
if not(ast.ast_equal(got2_rhs, ast('beta_2 * K_2')))
    error('Y_2 inline failed: got "%s"', got2_rhs.string())
end

% beta_1 and beta_2 should now be untyped symbols
if not(any(strcmp(m.getallsymbols(), 'beta_1'))) || not(any(strcmp(m.getallsymbols(), 'beta_2')))
    error('beta_i should have been added as new symbols')
end

fprintf('t07.m: All tests passed\n');
