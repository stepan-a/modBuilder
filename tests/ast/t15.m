% expand: distribute multiplication over addition and unroll integer powers of sums.

eq_canon = @(a, b) ast.ast_equal(a.simplify(), b.simplify());

% Single-distribute
n = ast('a*(b+c)').expand();
assert(eq_canon(n, ast('a*b + a*c')), 'a*(b+c) → a*b + a*c');

% Right-side distribute
n = ast('(b+c)*a').expand();
assert(eq_canon(n, ast('a*b + a*c')), '(b+c)*a → a*b + a*c');

% Cartesian product of two sums
n = ast('(a+b)*(c+d)').expand();
assert(eq_canon(n, ast('a*c + a*d + b*c + b*d')), '(a+b)*(c+d) → a*c + a*d + b*c + b*d');

% Triple Cartesian
n = ast('(a+b)*(c+d)*(e+f)').expand();
assert(eq_canon(n, ast('a*c*e + a*c*f + a*d*e + a*d*f + b*c*e + b*c*f + b*d*e + b*d*f')), 'triple Cartesian product');

% Power of a sum: multinomial theorem produces the canonical-coefficient form
n = ast('(a+b)^2').expand();
assert(eq_canon(n, ast('a^2 + 2*a*b + b^2')), '(a+b)^2 binomial');

n = ast('(a+b)^3').expand();
assert(eq_canon(n, ast('a^3 + 3*a^2*b + 3*a*b^2 + b^3')), '(a+b)^3 binomial');

n = ast('(a+b)^4').expand();
assert(eq_canon(n, ast('a^4 + 4*a^3*b + 6*a^2*b^2 + 4*a*b^3 + b^4')), '(a+b)^4 binomial');

% Multinomial for a 3-term sum
n = ast('(a+b+c)^2').expand();
assert(eq_canon(n, ast('a^2 + b^2 + c^2 + 2*a*b + 2*a*c + 2*b*c')), '(a+b+c)^2 multinomial');

n = ast('(a+b+c)^3').expand();
expected = ast('a^3 + b^3 + c^3 + 3*a^2*b + 3*a^2*c + 3*a*b^2 + 3*b^2*c + 3*a*c^2 + 3*b*c^2 + 6*a*b*c');
assert(eq_canon(n, expected), '(a+b+c)^3 multinomial');

% Identity: the binomial theorem applied symbolically and then subtracted
n = ast('(a+b)^3 - a^3 - 3*a^2*b - 3*a*b^2 - b^3').expand();
assert(eq_canon(n, ast('0')), '(a+b)^3 expansion identity');

% Power n=0 and n=1 are identities
assert(eq_canon(ast('(a+b)^0').expand(), ast('1')), '(a+b)^0 → 1');
assert(eq_canon(ast('(a+b)^1').expand(), ast('a + b')), '(a+b)^1 → a + b');

% Negative integer or non-integer powers are not unrolled (would need partial fractions)
n = ast('(a+b)^(-1)').expand();
assert(eq_canon(n, ast('(a+b)^(-1)')), '(a+b)^(-1) is not unrolled');

% Distribution combined with subtraction
n = ast('a*(b - c)').expand();
assert(eq_canon(n, ast('a*b - a*c')), 'a*(b - c) → a*b - a*c');

% The classic test of distributivity: identity
n = ast('a*(b+c) - a*b - a*c').expand();
assert(eq_canon(n, ast('0')), 'distributivity collapse');

% Higher-order identity: (a+b)^2 - a^2 - 2*a*b - b^2 = 0
n = ast('(a+b)^2 - a^2 - 2*a*b - b^2').expand();
assert(eq_canon(n, ast('0')), '(a+b)^2 expansion identity');

% Idempotent: expand of an already-expanded sum stays the same
n1 = ast('a*c + a*d + b*c + b*d').expand();
n2 = n1.expand();
assert(ast.ast_equal(n1, n2), 'expand is idempotent on a sum of products');
