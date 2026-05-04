% canonicalise: '-' rewritten as '+ uminus', '/' rewritten as '* ^(-1)',
% commutative chains flattened and sorted.

% Subtraction is rewritten with a unary minus on the right
n = ast('a - b').canonicalise();
expected = ast('binop', '+', {ast('sym', 'a', {}), ast('uminus', [], {ast('sym', 'b', {})})});
assert(ast.ast_equal(n, expected), 'a - b → a + (-b)');

% Division is rewritten as multiplication by an inverse
n = ast('a / b').canonicalise();
expected = ast('binop', '*', {ast('sym', 'a', {}), ast('binop', '^', {ast('sym', 'b', {}), ast('num', -1, {})})});
assert(ast.ast_equal(n, expected), 'a / b → a * b^(-1)');

% Commutative '+' chains are flattened and sorted lexicographically
% (b + a + c) → flatten {b, a, c} → sort {a, b, c} → ((a + b) + c)
n = ast('b + a + c').canonicalise();
expected = ast('(a + b) + c');
assert(ast.ast_equal(n, expected), 'b + a + c sorts to a + b + c');

% Same for '*'
n = ast('b * a * c').canonicalise();
expected = ast('(a * b) * c');
assert(ast.ast_equal(n, expected), 'b * a * c sorts to a * b * c');

% Numbers come before symbols in the sort order
n = ast('x + 5').canonicalise();
expected = ast('5 + x');
assert(ast.ast_equal(n, expected), 'numbers sort before symbols');

% Commutativity is detected across forms: a*b - b*a → 0 (both products
% canonicalise to the same a*b shape, which is then pair-cancelled in the '+' chain).
n = ast('a*b - b*a').canonicalise();
assert(ast.ast_equal(n, ast('num', 0, {})), 'a*b - b*a canonicalises to 0');

% Idempotent: canonicalise(canonicalise(t)) == canonicalise(t)
n1 = ast('alpha * x(-1) + beta').canonicalise();
n2 = n1.canonicalise();
assert(ast.ast_equal(n1, n2), 'canonicalise is idempotent');
