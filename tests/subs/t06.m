addpath ../utils

% subs: implicit loop with one $ placeholder, no eqname (apply to all equations).

m = modBuilder();
m.add('Y', 'Y = alpha_1*K_1 + alpha_2*K_2 + alpha_3*K_3');
m.parameter('alpha_$1', 0.3, {1, 2, 3});
m.exogenous('K_$1', 1.0, {1, 2, 3});

m.subs('alpha_$1', '0.3', {1, 2, 3});

got = m{'Y'}.equations{2};
LHSRHS = strsplit(got, '=');
got_rhs = ast(strtrim(LHSRHS{2}));
expected_rhs = ast('0.3*K_1 + 0.3*K_2 + 0.3*K_3');
if not(ast.ast_equal(got_rhs, expected_rhs))
    error('subs: implicit-loop expansion failed. expected "%s", got "%s"', expected_rhs.string(), got_rhs.string())
end

% all alpha_i must have been removed from the parameter list
for i = 1:3
    if m.isparameter(sprintf('alpha_%u', i))
        error('alpha_%u should have been removed', i)
    end
end

fprintf('t06.m: All tests passed\n');
