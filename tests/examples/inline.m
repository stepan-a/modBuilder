% Test examples from inline method documentation

addpath ../utils

% Example 1: Inline a defining variable everywhere, then drop the now-tautological equation.
m = modBuilder();
m.add('Y', 'Y = mc * X');
m.add('mc', 'mc = w / mpl');
m.exogenous('X', 1);
m.exogenous('w', 1);
m.exogenous('mpl', 1);

m.inline('mc', 'w / mpl');
m.remove('mc');

LHSRHS = strsplit(m{'Y'}.equations{2}, '=');
got = ast(strtrim(LHSRHS{2}));
if not(ast.ast_equal(got, ast('(w / mpl) * X')))
    error('Example 1 failed: expected Y RHS = (w/mpl)*X, got "%s"', LHSRHS{2})
end
if m.issymbol('mc')
    error('Example 1 failed: mc should have been removed')
end

fprintf('Example 1 passed: Inline a defining variable, then remove its equation\n');

% Example 2: Inline only into a specific equation, with a parameter in the replacement.
m = modBuilder();
m.add('Y', 'Y = mc * X');
m.add('mc', 'mc = w / mpl');
m.exogenous('X', 1);
m.exogenous('w', 1);
m.exogenous('mpl', 1);
m.parameter('theta', 6);

m.inline('mc', '(theta-1)/theta * w / mpl', 'Y');

LHSRHS = strsplit(m{'Y'}.equations{2}, '=');
got = ast(strtrim(LHSRHS{2}));
if not(ast.ast_equal(got, ast('(theta-1)/theta * w / mpl * X')))
    error('Example 2 failed: Y RHS mismatch, got "%s"', LHSRHS{2})
end

LHSRHS = strsplit(m{'mc'}.equations{2}, '=');
got = ast(strtrim(LHSRHS{2}));
if not(ast.ast_equal(got, ast('w / mpl')))
    error('Example 2 failed: mc equation should not be touched, got "%s"', LHSRHS{2})
end
if not(m.isparameter('theta'))
    error('Example 2 failed: theta should still be a parameter')
end

fprintf('Example 2 passed: Inline into a specific equation with a parameter in the replacement\n');

% Example 3: Implicit loop — inline alpha_i by a constant in every equation.
m = modBuilder();
m.add('Y', 'Y = alpha_1*K_1 + alpha_2*K_2 + alpha_3*K_3');
m.parameter('alpha_$1', 0.3, {1, 2, 3});
m.exogenous('K_$1', 1.0, {1, 2, 3});

m.inline('alpha_$1', '0.33', {1, 2, 3});

LHSRHS = strsplit(m{'Y'}.equations{2}, '=');
got = ast(strtrim(LHSRHS{2}));
if not(ast.ast_equal(got, ast('0.33*K_1 + 0.33*K_2 + 0.33*K_3')))
    error('Example 3 failed: Y RHS mismatch, got "%s"', LHSRHS{2})
end
for i = 1:3
    if m.isparameter(sprintf('alpha_%u', i))
        error('Example 3 failed: alpha_%u should have been removed', i)
    end
end

fprintf('Example 3 passed: Implicit loop with a constant replacement\n');

% Example 4: Implicit loop with eqname placeholder reuse.
m = modBuilder();
m.add('Y_1', 'Y_1 = alpha_1 * K_1');
m.add('Y_2', 'Y_2 = alpha_2 * K_2');
m.add('Y_3', 'Y_3 = alpha_3 * K_3');
m.parameter('alpha_$1', 0.3, {1, 2, 3});
m.exogenous('K_$1', 1.0, {1, 2, 3});

warning('off', 'backtrace')
m.inline('alpha_$1', 'beta_$1', 'Y_$1', {1, 2, 3});
warning('on', 'backtrace')

for i = 1:3
    eqname = sprintf('Y_%u', i);
    LHSRHS = strsplit(m{eqname}.equations{2}, '=');
    got = ast(strtrim(LHSRHS{2}));
    expected = ast(sprintf('beta_%u * K_%u', i, i));
    if not(ast.ast_equal(got, expected))
        error('Example 4 failed: %s RHS mismatch, got "%s"', eqname, LHSRHS{2})
    end
end

fprintf('Example 4 passed: Implicit loop with shared eqname placeholder\n');

fprintf('inline.m: All tests passed\n');
