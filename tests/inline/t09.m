addpath ../utils

% inline: implicit loop where eqname has a placeholder disjoint from varname.
% Inline mc into Y_1, Y_2 (no $ in mc, $1 only in eqname).

m = modBuilder();
m.add('Y_1', 'Y_1 = mc + 1');
m.add('Y_2', 'Y_2 = mc + 2');
m.add('Z',   'Z   = mc + 3');
m.add('mc',  'mc  = w / mpl');
m.exogenous('w', 1);
m.exogenous('mpl', 1);

m.inline('mc', 'w/mpl', 'Y_$1', {1, 2});

% Y_1 and Y_2 must reflect the substitution
got1 = m{'Y_1'}.equations{2};
LHSRHS = strsplit(got1, '=');
got1_rhs = ast(strtrim(LHSRHS{2}));
if not(ast.ast_equal(got1_rhs, ast('w/mpl + 1')))
    error('Y_1 inline failed: got "%s"', got1_rhs.string())
end

got2 = m{'Y_2'}.equations{2};
LHSRHS = strsplit(got2, '=');
got2_rhs = ast(strtrim(LHSRHS{2}));
if not(ast.ast_equal(got2_rhs, ast('w/mpl + 2')))
    error('Y_2 inline failed: got "%s"', got2_rhs.string())
end

% Z and the defining equation for mc must NOT have been touched
gotZ = m{'Z'}.equations{2};
LHSRHS = strsplit(gotZ, '=');
gotZ_rhs = ast(strtrim(LHSRHS{2}));
if not(ast.ast_equal(gotZ_rhs, ast('mc + 3')))
    error('Z should not have been touched: got "%s"', gotZ_rhs.string())
end

gotmc = m{'mc'}.equations{2};
LHSRHS = strsplit(gotmc, '=');
gotmc_rhs = ast(strtrim(LHSRHS{2}));
if not(ast.ast_equal(gotmc_rhs, ast('w / mpl')))
    error('mc defining equation should not have been touched: got "%s"', gotmc_rhs.string())
end

fprintf('t09.m: All tests passed\n');
