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
