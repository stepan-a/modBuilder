% Round-trip: parse → string → parse must produce structurally equal trees.

cases = {
    'alpha'
    '0.33'
    '1e-5'
    'a + b'
    'a + b + c'
    'a + b * c'
    '(a + b) * c'
    'a - b - c'
    'a - (b - c)'
    'a - (b + c)'
    'a + (b - c)'
    'a * b * c'
    'a * (b * c)'
    'a / b / c'
    'a / (b / c)'
    'a^b^c'
    '(a^b)^c'
    '(a + b)^c'
    'a^(b + c)'
    '-x'
    '-x*y'
    '-x^y'
    '-(x*y)'
    '-(x + y)'
    '(-x)^2'
    'exp(x)'
    'log(a + b)'
    'max(a, b)'
    'exp(-x^2)'
    'STEADY_STATE(K)'
    'alpha * K(-1)^theta * L^(1 - theta)'
    'alpha * GDP(-1) + beta * GDP(+1)'
    };

for i = 1:numel(cases)
    s = cases{i};
    t1 = ast(s);
    s2 = t1.string();
    t2 = ast(s2);
    assert(ast.ast_equal(t1, t2), sprintf('round-trip failed for "%s" → "%s"', s, s2));
end
