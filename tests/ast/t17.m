% replace_subtree: literal structural subtree replacement.

eq_canon = @(a, b) ast.ast_equal(a.simplify(), b.simplify());

% Literal subtree match
n = ast('alpha + (a + b)*c').replace_subtree(ast('a + b'), ast('z'));
assert(eq_canon(n, ast('alpha + z*c')), 'literal subtree replacement');

% Commutative reordering: target b+a matches a+b in the host (canonicalised)
n = ast('alpha + (a + b)*c').replace_subtree(ast('b + a'), ast('z'));
assert(eq_canon(n, ast('alpha + z*c')), 'commutative match: target b+a');

% Same for products: target b*a matches a*b in the host
n = ast('alpha + b*a + d').replace_subtree(ast('a*b'), ast('z'));
assert(eq_canon(n, ast('alpha + z + d')), 'commutative match: a*b vs b*a');

% Replace inside a function call argument
n = ast('exp(a + b) - 1').replace_subtree(ast('a + b'), ast('y'));
assert(eq_canon(n, ast('exp(y) - 1')), 'replacement inside a call');

% No match: target absent → tree unchanged (modulo canonicalisation)
n = ast('a + b').replace_subtree(ast('c'), ast('z'));
assert(eq_canon(n, ast('a + b')), 'no match: identity');

% Replace a STEADY_STATE pattern
n = ast('alpha + STEADY_STATE(K)').replace_subtree(ast('STEADY_STATE(K)'), ast('K_bar'));
assert(eq_canon(n, ast('alpha + K_bar')), 'STEADY_STATE pattern');

% Replace a tsym (specific lag) — does not touch the bare symbol or other lags
n = ast('x + x(-1) + x(+1)').replace_subtree(ast('x(-1)'), ast('z'));
assert(eq_canon(n, ast('x + z + x(+1)')), 'specific tsym replacement');

% Multiple matches: every occurrence is replaced
n = ast('(a+b)*c + (a+b)*d').replace_subtree(ast('a+b'), ast('z'));
assert(eq_canon(n, ast('z*c + z*d')), 'multiple occurrences');

% Replacement may itself be an expression
n = ast('alpha + (a*b)*c').replace_subtree(ast('a*b'), ast('p+q'));
assert(eq_canon(n, ast('alpha + (p+q)*c')), 'compound replacement');
