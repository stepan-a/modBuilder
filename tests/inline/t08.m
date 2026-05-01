addpath ../utils

% inline: implicit loop with two placeholders in varname/replacement.

m = modBuilder();
m.add('Y', 'Y = alpha_FR_1 + alpha_FR_2 + alpha_DE_1 + alpha_DE_2');
m.parameter('alpha_FR_1', 0.1);
m.parameter('alpha_FR_2', 0.2);
m.parameter('alpha_DE_1', 0.3);
m.parameter('alpha_DE_2', 0.4);

m.inline('alpha_$1_$2', 'beta_$1_$2', {'FR', 'DE'}, {1, 2});

got = m{'Y'}.equations{2};
LHSRHS = strsplit(got, '=');
got_rhs = ast(strtrim(LHSRHS{2}));
expected_rhs = ast('beta_FR_1 + beta_FR_2 + beta_DE_1 + beta_DE_2');
if not(ast.ast_equal(got_rhs, expected_rhs))
    error('inline: two-index expansion failed. expected "%s", got "%s"', expected_rhs.string(), got_rhs.string())
end

% all alpha_X_Y should have been removed
for cc = {'FR', 'DE'}
    for i = 1:2
        nm = sprintf('alpha_%s_%u', cc{1}, i);
        if m.isparameter(nm)
            error('%s should have been removed', nm)
        end
    end
end

fprintf('t08.m: All tests passed\n');
