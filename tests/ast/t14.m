% simplify on more involved expressions: commutative permutations of complex
% subtrees and self-divisions reduce to 0 because canonicalise normalises
% operand order and simplify catches the f-f / f/f patterns directly.

eq_canon = @(a, b) ast.ast_equal(a.canonicalise(), b.canonicalise());

% Commutative permutation with parenthesised additive subtrees
n = ast('(a + b)*(c - d) - (c - d)*(a + b)').simplify();
assert(eq_canon(n, ast('0')), 'commutative permutation: sums × sums');

% Function-call operands
n = ast('sin(x + 1)*log(y) - log(y)*sin(x + 1)').simplify();
assert(eq_canon(n, ast('0')), 'commutative permutation: function-call operands');

% Self-division of an additive expression
n = ast('(alpha*K + beta*L) / (alpha*K + beta*L) - 1').simplify();
assert(eq_canon(n, ast('0')), 'self-division of an additive expression');

% Self-division of a function-call expression
n = ast('exp(z + 1) / exp(z + 1) - 1').simplify();
assert(eq_canon(n, ast('0')), 'self-division of a function-call');

% Exponent equality across permuted base
n = ast('(alpha + beta)^2 - (beta + alpha)^2').simplify();
assert(eq_canon(n, ast('0')), 'permuted base inside ^');

% Mixed: parameter times a subtraction, and the same in reverse order
n = ast('alpha*(beta - gamma) - (beta - gamma)*alpha').simplify();
assert(eq_canon(n, ast('0')), 'parameter × subtraction, both orders');

% Dynamic (time-subscripted) operands: tsym nodes also sort correctly
n = ast('x(-1)*y(+1) - y(+1)*x(-1)').simplify();
assert(eq_canon(n, ast('0')), 'commutative permutation across leads/lags');

% Self-division involving leads / lags
n = ast('K(-1) / K(-1) - 1').simplify();
assert(eq_canon(n, ast('0')), 'self-division of a tsym');

% Division of a permuted product by itself
n = ast('(alpha*K) / (K*alpha) - 1').simplify();
assert(eq_canon(n, ast('0')), 'permuted product self-division');

% --- Pair-cancellation across flattened chains ---

% Partial cancellation in a long sum
n = ast('a + b - a').simplify();
assert(eq_canon(n, ast('b')), 'a + b - a → b');

% Partial cancellation of a permuted compound
n = ast('((a + b) * c + d) - (d + c * (b + a))').simplify();
assert(eq_canon(n, ast('0')), 'nested commutative chain cancels');

% Multiple cancellations in one chain
n = ast('a + b + c - a - b').simplify();
assert(eq_canon(n, ast('c')), 'a + b + c - a - b → c');

% Multiplicative pair-cancellation
n = ast('(a * b * c) / (a * c)').simplify();
assert(eq_canon(n, ast('b')), '(a*b*c) / (a*c) → b');

% Inverse pushed through a product
n = ast('a * b * (a*c)^(-1)').simplify();
% pushes (a*c)^(-1) through * to a^(-1) * c^(-1), then cancels (a, a^(-1))
% leaving b * c^(-1) (which renders as b/c)
assert(eq_canon(n, ast('b / c')), 'a*b*(a*c)^(-1) → b/c');

% Subtracting a negated expression: a - (-b) → a + b (no double-uminus left)
n = ast('a - (-b)').simplify();
assert(eq_canon(n, ast('a + b')), 'a - (-b) → a + b');

% Double negation collapses
n = ast('uminus', [], {ast('uminus', [], {ast('sym', 'x', {})})}).canonicalise();
assert(ast.ast_equal(n, ast('sym', 'x', {})), 'canonicalise removes double negation');
