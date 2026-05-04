% factor: extract a common multiplicative factor from a sum.

eq_canon = @(a, b) ast.ast_equal(a.simplify(), b.simplify());

% Basic factoring
n = ast('a*b + a*c').factor();
assert(eq_canon(n, ast('a * (b + c)')), 'a*b + a*c → a*(b+c)');

% More than two terms
n = ast('a*b + a*c + a*d').factor();
assert(eq_canon(n, ast('a * (b + c + d)')), 'three-term factoring');

% Common factor with multiplicity
n = ast('a*a*b + a*a*c').factor();
assert(eq_canon(n, ast('a*a * (b + c)')), 'common factor with multiplicity');

% Factor through a subtraction (the (-1) sits next to the factored term)
n = ast('a*b - a*c').factor();
assert(eq_canon(n, ast('a * (b - c)')), 'a*b - a*c → a*(b-c)');

% Common factor including a leading number
n = ast('2*a*b + 2*a*c').factor();
assert(eq_canon(n, ast('2*a * (b + c)')), '2*a*b + 2*a*c → 2*a*(b+c)');

% Common factor across subtraction with a numeric coefficient
n = ast('2*a*b - 2*a*c').factor();
assert(eq_canon(n, ast('2*a * (b - c)')), '2*a*b - 2*a*c → 2*a*(b-c)');

% Common denominator (a/b + c/b → (a+c)/b)
n = ast('a/b + c/b').factor();
assert(eq_canon(n, ast('(a + c) / b')), 'common denominator');

% Common denominator across subtraction
n = ast('a/b - c/b').factor();
assert(eq_canon(n, ast('(a - c) / b')), 'common denominator with subtraction');

% No common factor: tree unchanged
n1 = ast('a*b + c*d').factor();
n2 = ast('a*b + c*d').canonicalise();
assert(ast.ast_equal(n1, n2), 'no common factor: identity');

% expand ∘ factor on a factored sum reproduces the expanded form
n_in = ast('a*b + a*c + a*d');
n_factored = n_in.factor();
n_round = n_factored.expand();
assert(ast.ast_equal(n_round, n_in.canonicalise()), 'factor then expand reproduces the input');

% Numeric GCD of coefficients is also pulled out
assert(eq_canon(ast('4*a*b + 6*a*c').factor(), ast('2*a*(2*b + 3*c)')), '4ab + 6ac → 2a(2b+3c)');
assert(eq_canon(ast('6*x + 9*y').factor(), ast('3*(2*x + 3*y)')), '6x + 9y → 3(2x+3y)');

% Idempotent: factor of an already-factored expression stays the same
n1 = ast('a*b + a*c').factor();
n2 = n1.factor();
assert(ast.ast_equal(n1, n2), 'factor is idempotent');
